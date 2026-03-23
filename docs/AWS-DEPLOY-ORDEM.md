# Subir o ambiente FIAP no Learner Lab — ordem dos comandos

**Região:** `us-east-1` (obrigatório para par **vockey** / PEM do lab).  
**Passo a passo pelo console (sem CLI):** ver **[`AWS-DEPLOY-PORTAL.md`](./AWS-DEPLOY-PORTAL.md)**.  
**Onde rodar os comandos AWS CLI:** **CloudShell** no console (recomendado) ou PC com `aws` autenticado.

> **Terminal web Vocareum (`eee_*@runweb*`)**  
> Aí **não rode `docker login` / `docker push` / `docker build`**. Dá *permission denied* no `/var/run/docker.sock` e **não há sudo** para corrigir. Use **Docker no seu Windows** ou numa **EC2** que você criou.

---

## Parte 0 — Variáveis (rode uma vez por sessão)

```bash
export AWS_DEFAULT_REGION=us-east-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account: $ACCOUNT_ID"
```

---

## Parte 1 — DynamoDB (analytics)

Tabela alinhada ao app (`event_id` como chave).

```bash
aws dynamodb create-table \
  --table-name ToggleMasterAnalytics \
  --attribute-definitions AttributeName=event_id,AttributeType=S \
  --key-schema AttributeName=event_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --tags Key=Project,Value=FIAP

# Aguarde ACTIVE (30–60 s)
aws dynamodb wait table-exists --table-name ToggleMasterAnalytics
```

---

## Parte 2 — SQS (evaluation → analytics)

```bash
aws sqs create-queue --queue-name fiap-evaluation-events

export QUEUE_URL=$(aws sqs get-queue-url --queue-name fiap-evaluation-events --query QueueUrl --output text)
echo "Cole no .env como AWS_SQS_URL=$QUEUE_URL"
```

---

## Parte 3 — ECR (5 repositórios)

Lab: você tem write no console; CLI também cria repo.

```bash
for name in auth-service evaluation-service analytics-service flag-service targeting-service; do
  aws ecr create-repository --repository-name "$name" --image-scanning-configuration scanOnPush=true 2>/dev/null || true
done

# URLs para o Makefile (.env) — copie a saída
echo "AWS_AUTH_SERVICE_ECR=${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/"
echo "AWS_EVALUATION_SERVICE_ECR=${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/"
echo "AWS_ANALYTICS_SERVICE_ECR=${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/"
echo "AWS_FLAG_SERVICE_ECR=${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/"
echo "AWS_TARGETING_SERVICE_ECR=${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/"
```

**Login no ECR** (antes de `docker push` — Parte 6):

Na **EC2**, se aparecer *permission denied* em `/var/run/docker.sock`, use **`sudo docker`** até fazer logout/login após `sudo usermod -aG docker ec2-user`:

```bash
aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
```

> **CloudShell** não traz Docker para build/push; use **seu PC** (Docker Desktop) ou uma **EC2** com Docker.

---

## Parte 4 — Rede: Security Group (1 EC2, várias portas)

**Regra do lab:** não deixe recursos expostos sem necessidade. Substitua **`SEU_IP/32`** pelo seu IP público (ex.: pesquise “what is my ip”).

```bash
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query "Vpcs[0].VpcId" --output text)
export SG_ID=$(aws ec2 create-security-group \
  --group-name fiap-stack-sg \
  --description "FIAP docker compose" \
  --vpc-id "$VPC_ID" \
  --query GroupId --output text)

# SSH
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 189.110.37.217/32

# APIs (ajuste SEU_IP ou use mesmo CIDR do lab/professor)
for port in 8001 8002 8003 8004 8005; do
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port "$port" --cidr 189.110.37.217/32
done

echo "SG_ID=$SG_ID"
```

Se o enunciado pedir acesso aberto (não recomendado): `--cidr 0.0.0.0/0` só nas portas necessárias.

---

## Parte 5 — EC2 (Amazon Linux 2023, perfil do lab)

**Limites:** use **1 instância** (ex. `t3.small` ou `t2.medium`) para a stack inteira em Docker — economiza budget e respeita o limite de instâncias.

AMI mais recente AL2023 x86_64:

```bash
export AMI_ID=$(aws ssm get-parameters \
  --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameters[0].Value' --output text)

export SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=default-for-az,Values=true" \
  --query 'Subnets[0].SubnetId' --output text)
```

Subir a instância (**key `vockey`** em us-east-1; **LabInstanceProfile** para a role no host):

```bash
aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.small \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --associate-public-ip-address \
  --key-name vockey \
  --iam-instance-profile Name=LabInstanceProfile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=fiap-docker-host}]' \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
  --user-data file://scripts/ec2-user-data-docker.sh
```

> **CloudShell:** envie o arquivo `scripts/ec2-user-data-docker.sh` ou **remova** a linha `--user-data ...` e instale Docker na Parte 7.

```bash
export INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=fiap-docker-host" "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

# IP público (anote para SSH)
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

Se **não** usar `user-data`, instale Docker manualmente na Parte 7 (comandos abaixo).

---

## Parte 6 — Build e push das imagens (no seu PC ou na EC2)

No diretório do projeto, com Docker instalado e login ECR (Parte 3):

```bash
cd /caminho/do/FIAP-main   # ou clone na EC2

# Preencha .env com QUEUE_URL, ECR prefixes, AWS_REGION=us-east-1
make build
make push
```

Se `make push` falhar, faça login ECR de novo e confira variáveis `AWS_*_SERVICE_ECR` no `.env`.

---

## Parte 7 — Na EC2 (SSH)

```bash
ssh -i labsuser.pem ec2-user@IP_PUBLICO
```

**Se não usou user-data**, instale Docker + Compose plugin:

```bash
sudo dnf update -y -q
sudo dnf install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
# saia e entre de novo no SSH para grupo docker

sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -sSL "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
```

Clone o repo (ou envie com `scp`), ajuste `.env`:

- `AWS_SQS_URL` = URL da Parte 2  
- `AWS_DYNAMODB_TABLE=ToggleMasterAnalytics`  
- `AWS_REGION=us-east-1`  
- Imagens: troque `image: auth-service:v1` etc. no `docker-compose.yml` **ou** no `.env` use tags ECR, **ou** mais simples: no host rode `docker pull` das 5 imagens do ECR e retague `auth-service:v1` — o compose atual usa nomes locais.

**Opção simples na EC2** (após push):

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REG="${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
for s in auth-service evaluation-service analytics-service flag-service targeting-service; do
  docker pull "$REG/$s:v1"
  docker tag "$REG/$s:v1" "$s:v1"
done
```

**Analytics + credenciais:** o container precisa de AWS. Na EC2 com **LabInstanceProfile**, gere credenciais temporárias e exporte **antes** do `docker compose up` (válidas ~1 h; renove se necessário):

```bash
TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
ROLE_NAME=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/)
CREDS=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME")
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r .AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r .SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r .Token)
```

No mesmo shell, **antes** de subir o compose, garanta que o `docker-compose.yml` passe essas variáveis ao **analytics-service** (ou estenda o compose). **Atalho rápido:** no `.env` do projeto, se o lab permitir outro método, use o que o professor indicar.

Se o compose **não** injeta `AWS_ACCESS_KEY_ID` no analytics, adicione ao serviço `analytics-service`:

```yaml
environment:
  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
  AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
  AWS_SESSION_TOKEN: ${AWS_SESSION_TOKEN}
```

(ou use um `env_file` gerado na EC2).

**Ordem após credenciais + imagens:**

1. `docker compose up -d`  
2. Criar chave API: `curl -X POST http://localhost:8001/admin/keys -H "Authorization: Bearer admin-secreto-123" -H "Content-Type: application/json" -d '{"name":"eval"}'`  
3. Colocar a `key` retornada em `SERVICE_API_KEY` no `.env`, reiniciar só o evaluation:  
   `docker compose up -d evaluation-service`

---

## Ordem resumida (checklist)

| # | Onde | Ação |
|---|------|------|
| 1 | CloudShell | Variáveis + DynamoDB + SQS |
| 2 | CloudShell | ECR repos + anotar URLs |
| 3 | CloudShell | SG + EC2 (vockey + LabInstanceProfile) |
| 4 | PC ou EC2 | `docker login` ECR → `make build` → `make push` |
| 5 | EC2 | SSH → Docker → pull/tag → `.env` → credenciais analytics → `docker compose up -d` |
| 6 | EC2 | Criar API key no auth → atualizar `SERVICE_API_KEY` → restart evaluation |

---

## Economia de budget (regras do lab)

- **1 EC2** para tudo (Compose), **parar/terminar** quando não usar.  
- **Sem** NAT Gateway só para teste (caro).  
- Tamanhos: **t3.small** ou menor se aguentar memória (vários containers).  
- Lembrete: ao **reiniciar** sessão do lab, EC2 pode **subir de novo** e o **IP público muda** — atualize SG se usar IP fixo no firewall, ou use **Elastic IP** se o lab permitir e valer a pena.

# FIAP no Learner Lab — passo a passo pelo **Console AWS** (portal)

**Região:** no canto superior direito do console, escolha **`N. Virginia` (`us-east-1`)** — necessário para a chave **vockey** / PEM do lab.

> Guia em CLI: [`AWS-DEPLOY-ORDEM.md`](./AWS-DEPLOY-ORDEM.md).  
> Build/push Docker e SSH na EC2 **não** são feitos pelo portal; use seu PC ou terminal na EC2.

---

## Antes de começar

1. Faça login no **AWS Console** da conta do lab.
2. Confirme **região `us-east-1`**.
3. Anote o **ID da conta** (menu superior direito → nome da conta → *Account ID* de 12 dígitos).  
   O prefixo ECR será: **`SEU_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/`**

---

## 1. DynamoDB (analytics)

1. Busque **DynamoDB** na barra de serviços → **Tables** → **Create table**.
2. **Table name:** `ToggleMasterAnalytics`
3. **Partition key:** `event_id` — tipo **String**.
4. **Table settings:** escolha **Default settings** ou, em **Customize settings**:
   - **Table class:** Standard
   - **Capacity mode:** **On-demand** (equivale a PAY_PER_REQUEST)
5. (Opcional) **Tags:** `Project` = `FIAP`
6. **Create table** e aguarde status **Active**.

No `.env`: `AWS_DYNAMODB_TABLE=ToggleMasterAnalytics` e `AWS_REGION=us-east-1`.

### Aviso AWS: console “novo” do DynamoDB, VPC e permissões

A AWS comunicou que a **experiência antiga** do console DynamoDB foi descontinuada (a partir de **15/out/2024**). O console novo pode usar caminhos como **`/api-proxy/prod/query`**. Isso afeta sobretudo **empresas e contas com acesso ao console só por VPC / PrivateLink / VPN**.

| Se você é… | O que fazer |
|------------|-------------|
| **Aluno no Learner Lab** acessando o console **pela internet** (navegador em casa/escola, sem console “privado” por VPC) | Em geral **não precisa** mudar política IAM nem PrivateLink. Se o DynamoDB abrir normalmente, ignore o aviso. |
| **Time de cloud / conta corporativa** com console restrito a VPC ou políticas IAM muito fechadas | (1) Ajustar políticas **baseadas em identidade ou em recurso** com condições **`aws:SourceIp`** e/ou **`aws:SourceVPC`** para permitir o tráfego legítimo do console via sua VPC. (2) Usar **acesso privado ao Console de Gerenciamento** via **endpoint de VPC**, conforme a documentação AWS. (3) Garantir que **VPN e firewall** liberem o tráfego necessário, incluindo rotas para **`/api-proxy/prod/query`** (e demais hosts do console indicados na doc AWS). |

**Resumo:** o aviso é sobre **como a organização permite acessar o console**, não sobre criar a tabela `ToggleMasterAnalytics`. O app FIAP continua usando DynamoDB por API/credenciais como antes.  
Documentação oficial: busque no site da AWS por *DynamoDB console VPC PrivateLink* e *Management Console private access*.

---

## 2. SQS (evaluation → analytics)

1. **Simple Queue Service (SQS)** → **Create queue**.
2. **Type:** Standard.
3. **Name:** `fiap-evaluation-events`
4. Deixe o restante em padrão (ou conforme o enunciado) → **Create queue**.
5. Abra a fila criada e copie a **URL** (ex.: `https://sqs.us-east-1.amazonaws.com/123456789012/fiap-evaluation-events`).

No `.env`: `AWS_SQS_URL=<URL copiada>`.

---

## 3. ECR — 5 repositórios de imagem

1. **Elastic Container Registry** → **Repositories** → **Create repository** (repita para cada nome ou crie um a um).
2. Para **cada** repositório:
   - **Visibility:** Private
   - **Repository name** (exatamente):
     - `auth-service`
     - `evaluation-service`
     - `analytics-service`
     - `flag-service`
     - `targeting-service`
   - Em **Image scan settings:** ative **Scan on push** (recomendado).
3. **Create repository**.

**URLs para o `.env` (todas usam o mesmo host, só muda o nome do repo no push):**

| Variável no `.env` | Valor (substitua `ACCOUNT_ID`) |
|--------------------|--------------------------------|
| `AWS_AUTH_SERVICE_ECR` | `ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/` |
| `AWS_EVALUATION_SERVICE_ECR` | idem |
| `AWS_ANALYTICS_SERVICE_ECR` | idem |
| `AWS_FLAG_SERVICE_ECR` | idem |
| `AWS_TARGETING_SERVICE_ECR` | idem |

O **login** no ECR para `docker push` continua sendo por terminal (`aws ecr get-login-password` …) — o portal só mostra os repositórios e as URIs das imagens depois do push.

---

## 4. IAM (LabRole / LabInstanceProfile) para SQS + DynamoDB + ECR

O FIAP (containers) vai precisar de uma permissão via **role/instance profile** na EC2 para acessar:

- **SQS** (`fiap-evaluation-events`) — `evaluation-service` envia; `analytics-service` recebe e deleta
- **DynamoDB** (`ToggleMasterAnalytics`) — `analytics-service` grava (`PutItem`)
- **ECR** — a EC2 precisa ter acesso para fazer `docker pull` das imagens

### No Learner Lab (recomendado)

No próprio lab, normalmente existe uma **role pré-configurada** para você usar:

1. Na etapa de criação da EC2 (aba **Advanced details**), procure **IAM instance profile**.
2. Selecione **`LabInstanceProfile`**.
3. Se não existir, avance para a seção opcional abaixo (criação manual) ou peça ao instrutor para liberar a role correta.

### (Opcional) Se você precisar criar do zero (portal)

1. IAM → **Roles** → **Create role**
2. Trusted entity type: **AWS service** → escolha **EC2**
3. Role name: pode ser `fiap-ec2-role`
4. Em Permissions policies, crie/cole uma policy com acesso mínimo (substitua `ACCOUNT_ID` e nomes):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SQSWriteReadForFIAP",
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:us-east-1:ACCOUNT_ID:fiap-evaluation-events"
    },
    {
      "Sid": "DynamoDBWriteForFIAP",
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:ACCOUNT_ID:table/ToggleMasterAnalytics"
    },
    {
      "Sid": "ECRPullForFIAP",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
```

5. IAM → **Instance profiles** → **Create instance profile**
6. Nome: **`LabInstanceProfile`** (ou ajuste a sua seção de EC2 para apontar para o nome que você criou)
7. Add role: selecione a role `fiap-ec2-role`

---

## 5. Security Group (firewall da EC2)

1. **VPC** → **Security Groups** → **Create security group**.
2. **Name:** ex. `fiap-stack-sg`  
   **Description:** ex. `FIAP docker compose`  
   **VPC:** selecione a **default VPC** do lab.
3. **Inbound rules** — **Add rule** para cada linha abaixo (substitua **seu IP** por `x.x.x.x/32`; descubra em “what is my ip”):

   | Type        | Port range | Source   |
   |-------------|------------|----------|
   | SSH         | 22         | Meu IP / `SEU_IP/32` |
   | Custom TCP  | 8001       | `SEU_IP/32` |
   | Custom TCP  | 8002       | `SEU_IP/32` |
   | Custom TCP  | 8003       | `SEU_IP/32` |
   | Custom TCP  | 8004       | `SEU_IP/32` |
   | Custom TCP  | 8005       | `SEU_IP/32` |

4. **Create security group** e anote o **Security group ID** (`sg-...`).

> Se o enunciado exigir aberto ao mundo (não recomendado), use **0.0.0.0/0** só nas portas pedidas.

---

## 6. EC2 (máquina para Docker Compose)

1. **EC2** → **Launch instance**.
2. **Name:** ex. `fiap-docker-host`
3. **Application and OS Images (AMI):**  
   **Amazon Linux** → **Amazon Linux 2023 AMI** — arquitetura **64-bit (x86)**.
4. **Instance type:** `t3.small` (ou `t2.medium` se o lab permitir e precisar de mais RAM).
5. **Key pair:** selecione **vockey** (deve existir em us-east-1 no lab).
6. **Network settings** → **Edit**:
   - **VPC / Subnet:** default (qualquer subnet pública/default que receba IP público).
   - **Auto-assign public IP:** **Enable**.
   - **Firewall (security groups):** selecione o grupo **`fiap-stack-sg`** criado acima (não o “launch-wizard” genérico, a menos que tenha as mesmas portas).
7. **Configure storage:** **30 GiB**, **gp3** (ajuste se o console mostrar mínimo diferente).
8. **Advanced details** (expandir):
   - **IAM instance profile:** **LabInstanceProfile** (nome exato do lab — necessário para o analytics usar credenciais da instância).
   - **User data** (opcional): cole o conteúdo do arquivo **`scripts/ec2-user-data-docker.sh`** do repositório (texto puro) para instalar Docker e Compose na primeira subida.  
     Se deixar em branco, você instala Docker manualmente depois do SSH (veja `AWS-DEPLOY-ORDEM.md` Parte 7).
9. **Launch instance**.

**Depois de Running:**

- Na lista de instâncias, selecione a máquina → copie **Public IPv4 address** para o SSH:  
  `ssh -i labsuser.pem ec2-user@IP_PUBLICO`

---

## 7. O que não dá para fazer só no portal (e sequência “final”)

| Etapa | Onde fazer |
|-------|------------|
| Build das imagens | PC com Docker ou na EC2 após SSH |
| `docker login` no ECR + `make push` | Terminal (AWS CLI + Docker) |
| `docker compose up` | SSH na EC2 |
| Credenciais temporárias para o container **analytics** | Terminal na EC2 (metadata IAM) — ver `AWS-DEPLOY-ORDEM.md` |
| Criar **API key** do auth e colar em `SERVICE_API_KEY` | **CloudShell** (portal) via `curl` contra `http://EC2_IP_PUBLIC:8001/admin/keys` |

### Gerar a `SERVICE_API_KEY` (via CloudShell, portal)

1. No console AWS, abra **EC2 → Instances** e copie o **Public IPv4 address** da sua instância.
   - Vamos chamar de `EC2_IP_PUBLIC`.
2. No seu projeto, abra o arquivo `.env` e confirme qual valor está em `MASTER_KEY`.
   - Vamos chamar de `MASTER_KEY_ATUAL`.
3. No console, clique em **CloudShell** (o terminal web) e rode (substitua os valores):

```bash
curl -sS -X POST "http://EC2_IP_PUBLIC:8001/admin/keys" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer MASTER_KEY_ATUAL" \
  -d "{\"name\":\"evaluation-service\"}"
```

4. O comando vai responder um JSON com a propriedade `key` (começa com `tm_key_...`).
5. Troque no seu arquivo `.env`:
   - de `SERVICE_API_KEY=chave_secreta`
   - para `SERVICE_API_KEY=<valor key retornado>`

6. Depois, via **SSH na EC2**, reinicie apenas o serviço `evaluation-service` para ele usar a chave nova:

```bash
cd /caminho/para/o/projeto   # diretório que contém docker-compose.yml e .env
docker compose up -d evaluation-service
```

---

## Checklist resumido (portal + pós-portal)

| # | No console AWS |
|---|----------------|
| 1 | Região **us-east-1** |
| 2 | DynamoDB: tabela **ToggleMasterAnalytics**, chave **event_id** (String), on-demand |
| 3 | SQS: fila **fiap-evaluation-events** → copiar URL |
| 4 | ECR: 5 repositórios privados + scan on push |
| 5 | IAM: **LabInstanceProfile** (ou role equivalente) com acesso a SQS + DynamoDB + ECR pull |
| 6 | Security group: 22 + 8001–8005 (seu IP) |
| 7 | EC2: AL2023, t3.small, vockey, IP público, **LabInstanceProfile**, SG acima, disco 30 GiB |

| # | Fora do portal |
|---|----------------|
| 8 | Preencher `.env` (ECR, SQS, DynamoDB, região) |
| 9 | `make build` + `make push` no PC |
| 10 | Na EC2: pull/tag imagens, `.env`, credenciais analytics, `docker compose up -d` |
| 11 | POST `/admin/keys` (via CloudShell) → `SERVICE_API_KEY` → restart **evaluation-service** |

---

## Economia de budget (igual ao guia CLI)

- Uma **só EC2** para a stack; **Stop/Terminate** quando não usar.  
- Evite **NAT Gateway** só para teste.  
- Se o **IP público** mudar após reiniciar o lab, **edite as regras inbound** do security group com o novo IP.

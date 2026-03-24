# Guia completo — AWS Academy (LabRole) + EKS (Fase 2)

Este guia é para executar a **Parte 2 (Nuvem/Kubernetes)** do Tech Challenge Fase 2 **no AWS Academy / Learner Lab**, seguindo a **Opção A** do PDF:

- **Não criar roles novas** (limitação do Academy) → usar **`LabRole`**.
- Escalabilidade com **HPA por CPU** (sem KEDA).
- Exposição externa com **Nginx Ingress Controller**.

> **Região recomendada:** `us-east-1` (N. Virginia), para evitar conflitos com key/limites do lab.

---

## 0) Checklist do que você vai criar na AWS

Você precisa desses recursos na nuvem:

- **EKS**: 1 cluster + 1 managed node group (com Auto Scaling).
- **ECR**: 5 repositórios (um por microsserviço).
- **RDS (PostgreSQL)**: 3 instâncias (auth, flag, targeting).
- **ElastiCache (Redis)**: 1 cluster (evaluation).
- **DynamoDB**: 1 tabela (`ToggleMasterAnalytics`, PK `event_id` string).
- **SQS**: 1 fila Standard (evaluation produz, analytics consome).

No Kubernetes você vai instalar:

- `metrics-server` (obrigatório pro HPA)
- `ingress-nginx` (para gerar Load Balancer e rotear `/auth`, `/flags`, etc.)

> Nota: o **Console AWS** permite provisionar toda a infraestrutura, mas a instalação desses componentes *dentro* do cluster e a aplicação dos manifestos YAML normalmente exige acesso ao cluster (via `kubectl`). Neste guia “somente Console”, eu descrevo o provisionamento e deixo a implantação como passo final “fora do Console”.

---

## 1) EKS (Console) — criar cluster usando LabRole `ok`

1. AWS Console → **EKS** → **Add cluster** → **Create**.
2. **Name**: ex. `fiap-fase2`.
3. **Kubernetes version**: a mais recente disponível (padrão).
4. **Cluster service role**: selecione **`LabRole`**.
5. **Networking**:
   - Use a VPC padrão do lab, se não houver orientação diferente.
   - Subnets: selecione as subnets padrão.
6. **Create** e aguarde status **ACTIVE**.

### 1.1) Node Group (Managed Node Group) — usar LabRole `ok`

1. No cluster → aba **Compute** → **Add node group**.
2. **Node IAM role**: selecione **`LabRole`** (isso é o ponto crítico no Academy).d
3. **Instance type**: escolha um tipo permitido pelo lab (ex.: `ccdw`/`t3.medium` conforme disponibilidade).
4. **Scaling configuration** (exemplo do PDF):
   - Min = 1
   - Desired = 2
   - Max = 4  
5. Criar e aguardar ficar **ACTIVE**.

---

## 2) ECR (Console) — criar 5 repositórios `ok`

### 3.1) Criar repositórios no ECR (Console)

AWS Console → **ECR** → **Repositories** → **Create repository** (Private).

Crie exatamente estes 5:

- `auth-service`
- `flag-service`
- `targeting-service`
- `evaluation-service`
- `analytics-service`

### 2.1) (Console) URIs/endereços do ECR `ok`

Depois de criar os repositórios, abra cada um e anote:

- **Repository URI** (ex.: `ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/auth-service`)

Você vai precisar das URIs para publicar as imagens (essa publicação é feita fora do Console, com Docker).

---

## 3) RDS (Console) — criar 3 instâncias PostgreSQL

Você precisa de 3 bancos gerenciados (um por serviço relacional):

- `auth-service` (Postgres)
- `flag-service` (Postgres)
- `targeting-service` (Postgres)

### 3.1) Console (RDS)

AWS Console → **RDS** → **Create database**

Sugestões (adequar ao lab/free tier):

- Engine: PostgreSQL
- Template: Dev/Test (ou Free Tier se disponível)
- Public access: **No** (recomendado)
- VPC/Security group: permita acesso a partir dos nodes do EKS (mesma VPC/SG conforme console)
- Anote:
  - **Endpoint** (host)
  - **DB name**
  - **username**
  - **password**

> Você vai colar esses valores no `.env` (seção RDS) e nos Secrets renderizados.

---

## 4) ElastiCache (Console) — criar Redis (evaluation-service)

AWS Console → **ElastiCache** → Redis → Create cluster.

- Anote o **endpoint** (host) e porta (geralmente 6379).
- Garanta conectividade de rede entre EKS nodes e Redis (VPC/SG).

---

## 5) DynamoDB (Console) — criar tabela do analytics

AWS Console → **DynamoDB** → Tables → Create table:

- Table name: `ToggleMasterAnalytics`
- Partition key: `event_id` (String)
- Capacity: On-demand (PAY_PER_REQUEST)

---

## 6) SQS (Console) — criar fila de eventos

AWS Console → **SQS** → Create queue:

- Type: Standard
- Name: ex. `fiap-evaluation-events`
- Copie a **Queue URL** (vai no `.env` como `SQS_QUEUE_URL`)

---

## 7) Acessar o cluster (kubectl) — Academy

Você precisa de `kubectl` para instalar add-ons (metrics-server/ingress) e aplicar os YAMLs do projeto.

### 7.1) Configurar acesso (AWS CLI + kubectl)

No seu PC (ou CloudShell), rode:

```bash
aws eks update-kubeconfig --region us-east-1 --name <NOME_DO_CLUSTER>
kubectl get nodes
```

> Se `kubectl get nodes` listar os nós, você está conectado.

---

## 8) Instalar Metrics Server (obrigatório pro HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl get deployment -n kube-system metrics-server
kubectl top nodes
```

---

## 9) Instalar Nginx Ingress Controller (cria Load Balancer)

### 9.1) Via Helm (recomendado se disponível)

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer
```

Depois, pegue o endereço do Load Balancer:

```bash
kubectl get svc -n ingress-nginx
```

---

## 10) Publicar imagens no ECR (PC com Docker)

Mesmo criando o ECR pelo Console, o push das imagens precisa de Docker.

1) Login no ECR:

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
```

2) No repo, ajuste `.env` (ou use `.env.eks.example` como base) e rode:

```bash
make build
make push
```

---

## 11) Preparar `.env` do Kubernetes e aplicar manifests

### 11.1) Criar `.env` a partir do exemplo EKS

Na raiz do projeto:

1. Copie `.env.eks.example` → `.env`
2. Preencha:
   - `AWS_*_SERVICE_ECR` (prefixos ECR)
   - `SQS_QUEUE_URL`
   - `AWS_DYNAMODB_TABLE`
   - `ELASTICACHE_ENDPOINT`
   - `RDS_*` (3 bancos)
   - `MASTER_KEY`
   - `SERVICE_API_KEY` (você preenche depois de gerar no cluster)

### 11.2) Renderizar manifests (ECR + endpoints)

```bash
./scripts/render-k8s-manifests.sh
```

### 11.3) Aplicar no cluster

```bash
./scripts/k8s-apply.sh
kubectl get pods -A
kubectl get ingress -A
kubectl get hpa -A
```

---

## 12) Gerar `SERVICE_API_KEY` no cluster (auth → evaluation)

1) Descubra o LB do ingress-nginx:

```bash
kubectl get svc -n ingress-nginx
```

2) Crie a chave via Ingress:

```bash
LB="http://SEU-LB"
MASTER_KEY="admin-secreto-123"

curl -sS -X POST "$LB/auth/admin/keys" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{"name":"evaluation-service"}'
```

3) Coloque o `key` retornado no `.env` (`SERVICE_API_KEY=tm_key_...`) e reaplique:

```bash
./scripts/render-k8s-manifests.sh
kubectl apply -f k8s-rendered/evaluation/secret-evaluation.yml
kubectl rollout restart deployment -n evaluation evaluation-service
```

---

## 13) Validar Ingress (curl externo)

```bash
LB="http://SEU-LB"
curl -sS "$LB/auth/health"; echo
curl -sS "$LB/flags/health"; echo
curl -sS "$LB/targeting/health"; echo
curl -sS "$LB/evaluation/health"; echo
```

---

## 14) Escalabilidade (HPA) — comandos do vídeo

```bash
kubectl get hpa -A
kubectl get pods -n evaluation
kubectl get pods -n analytics
```

Gerar carga no evaluation:

```bash
hey -z 60s -c 50 "$LB/evaluation/evaluate?user_id=user-123&flag_name=enable-new-dashboard"
```

---

## Problemas comuns (Academy) e como resolver

- **Ingress não cria Load Balancer**:
  - Verifique se o `ingress-nginx` está com `service.type=LoadBalancer`.
  - Verifique permissões do node group (no Academy: usar `LabRole` no node).

- **Pods não acessam RDS/ElastiCache**:
  - Segurança de rede (Security Groups/Subnets) na mesma VPC do EKS.
  - Regras inbound do SG do RDS/Redis permitindo tráfego a partir do SG dos nodes.

- **Analytics sem credenciais**:
  - No Academy, o acesso AWS vem da role do node group (LabRole). Não injete `AWS_ACCESS_KEY_ID` em secrets no cluster.

---

> **CloudShell:** Para usar CLI em vez do Console, veja [`docs/AWS-ACADEMY-CLOUDSHELL.md`](./AWS-ACADEMY-CLOUDSHELL.md).


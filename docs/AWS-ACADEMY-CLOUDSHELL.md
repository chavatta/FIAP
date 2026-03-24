# Guia CloudShell — AWS Academy + EKS (Fase 2)

Comandos para provisionar a infraestrutura do Tech Challenge Fase 2 via **AWS CloudShell** (CLI), em vez do Console.

> **Pré-requisito:** Estar logado no AWS Academy e com o lab ativo.  
> **Região:** `us-east-1` (N. Virginia).

---

## Variáveis de ambiente

```bash
export REGION=us-east-1
export CLUSTER_NAME=fiap-fase2
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

---

## 1) Instalar kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
kubectl version --client
```

---

## 2) ECR — criar 5 repositórios

```bash
for repo in auth-service flag-service targeting-service evaluation-service analytics-service; do
  aws ecr create-repository --repository-name $repo --region $REGION 2>/dev/null || echo "$repo já existe"
done
```

---

## 3) DynamoDB — criar tabela

```bash
aws dynamodb create-table \
  --table-name ToggleMasterAnalytics \
  --attribute-definitions AttributeName=event_id,AttributeType=S \
  --key-schema AttributeName=event_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION 2>/dev/null || echo "Tabela já existe"
```

---

## 4) SQS — criar fila

```bash
aws sqs create-queue \
  --queue-name fiap-evaluation-events \
  --region $REGION 2>/dev/null || echo "Fila já existe"

# Obter URL (use no .env como SQS_QUEUE_URL)
aws sqs get-queue-url --queue-name fiap-evaluation-events --region $REGION --query 'QueueUrl' --output text
```

---

## 5) EKS — criar cluster

```bash
# Obter VPC e subnets padrão
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text --region $REGION)
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text --region $REGION | tr '\t' ',')
SG_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=default" --query 'SecurityGroups[0].GroupId' --output text --region $REGION)

aws eks create-cluster \
  --name $CLUSTER_NAME \
  --version 1.31 \
  --role-arn arn:aws:iam::${ACCOUNT_ID}:role/LabRole \
  --resources-vpc-config subnetIds=$SUBNETS,securityGroupIds=$SG_ID,endpointPublicAccess=true,endpointPrivateAccess=false \
  --region $REGION

# Aguardar cluster ficar ACTIVE (5–10 min)
aws eks wait cluster-active --name $CLUSTER_NAME --region $REGION
```

---

## 6) EKS — criar node group

> Se `ng-fiap` já existir, delete antes:  
> `aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name ng-fiap --region $REGION`

```bash
SUBNETS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.subnetIds' --output text | tr '\t' ' ')

aws eks create-nodegroup \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name ng-fiap \
  --node-role arn:aws:iam::${ACCOUNT_ID}:role/LabRole \
  --subnets $SUBNETS \
  --instance-types t3.small \
  --scaling-config minSize=1,maxSize=4,desiredSize=2 \
  --disk-size 20 \
  --ami-type AL2023_x86_64_STANDARD \
  --region $REGION

# Aguardar node group ficar ACTIVE
aws eks wait nodegroup-active --cluster-name $CLUSTER_NAME --nodegroup-name ng-fiap --region $REGION
```

---

## 7) Configurar kubectl

```bash
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
kubectl get nodes
```

Se retornar **401 Unauthorized**, configure os Access entries no Console (EKS → Access): adicione `AmazonEKSClusterAdminPolicy` para o role **voclabs**.

---

## 8) Metrics Server + Ingress

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer
```

---

## RDS e ElastiCache

Crie pelo **Console** (RDS pode ser bloqueado em alguns labs; ElastiCache usa configuração de rede mais complexa). Ver `docs/AWS-ACADEMY-EKS-GUIA-COMPLETO.md`.

---

## Deploy da aplicação

O CloudShell não tem Docker; o **push das imagens** deve ser feito no seu PC.

Antes dos scripts, instale **gettext** (fornece `envsubst`):

```bash
sudo dnf install -y gettext
chmod +x scripts/render-k8s-manifests.sh scripts/k8s-apply.sh
```

No CloudShell, após ter RDS/ElastiCache e as imagens no ECR:

```bash
git clone https://github.com/chavatta/FIAP.git && cd FIAP
cp .env.eks.example .env
# Edite .env (nano .env) com ECR, SQS, RDS, ElastiCache, etc.
./scripts/render-k8s-manifests.sh
./scripts/k8s-apply.sh
```

---

## Referência

Guia completo (Console): [`docs/AWS-ACADEMY-EKS-GUIA-COMPLETO.md`](./AWS-ACADEMY-EKS-GUIA-COMPLETO.md)

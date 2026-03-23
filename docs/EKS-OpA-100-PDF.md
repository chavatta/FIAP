# EKS (Opção A / AWS Academy - LabRole) - Checklist 100% do PDF

Este documento complementa o enunciado da *Fase 2* com os passos que faltam no repo para bater com o checklist do PDF:

1. Cluster EKS (criado via Console, não `eksctl`)
2. Node group com `LabRole` (sem criar roles novas)
3. `metrics-server` (obrigatório para HPA)
4. `ingress-nginx` (para criar o Load Balancer e expor os endpoints via Ingress)
5. RDS (3x PostgreSQL) e ElastiCache (Redis gerenciado)

## 0) Pré-requisitos

- Região: `us-east-1`
- Você tem acesso ao AWS Console e ao `kubectl` apontando para o cluster.
- Para o PDF (Opção A), você deve usar a role existente `LabRole` quando o console pedir:
  - Cluster role
  - Node IAM role (managed node group)

## 1) Provisionar o cluster EKS (via Console)

1. AWS Console -> EKS -> **Create cluster**
2. Selecione:
   - **Cluster role**: `LabRole`
3. Em **Networking / VPC**, use a VPC padrão do lab (se não houver orientação diferente).
4. Em **Create managed node group**:
   - Node IAM role: `LabRole`
   - Autoscaling (exemplo do PDF): Min=1, Desired=2, Max=4
5. Espere o cluster ficar `ACTIVE`.

## 2) Configurar `kubectl`

1. Localize o nome do cluster (ex.: `fiap-fase2`)
2. Rode:

```bash
aws eks update-kubeconfig --region us-east-1 --name <NOME_DO_CLUSTER>
```

## 3) Instalar `metrics-server` (obrigatório para HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Garanta que o deployment ficou em `Ready`:

```bash
kubectl get deployment -n kube-system metrics-server
kubectl top nodes
```

## 4) Instalar `ingress-nginx`

Instale o controller `ingress-nginx` (via Helm ou `kubectl apply`) e garanta que a Service do controller fique como `LoadBalancer` para criar o LB na AWS.

Sugestao (Helm - se o lab permitir Helm):

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer
```

Se não puder usar Helm, instale via manifesto oficial do ingress-nginx e mantenha `service.type=LoadBalancer`.

## 5) Provisionar RDS (3 PostgreSQL) e ElastiCache (Redis)

Crie:

1. RDS PostgreSQL (auth-service)
   - 1 instância
2. RDS PostgreSQL (flag-service)
   - 1 instância
3. RDS PostgreSQL (targeting-service)
   - 1 instância
4. ElastiCache Redis (evaluation-service)
   - 1 cluster Redis

Anote:

- endpoint/host, porta (5432 para Postgres e 6379 para Redis)
- database name
- username e password

Depois, atualize:

- `auth-service/k8s/secret-auth.yml` (DATABASE_URL)
- `flag-service/k8s/secret-flag.yml` (FLAG_DATABASE_URL)
- `targeting-service/k8s/secret-targeting.yml` (TARGETING_DATABASE_URL)
- `evaluation-service/k8s/configMap-evaluation.yml` (REDIS_URL)

## 6) ECR / imagens (já tratado no repo)

O repo já tem passos para criar 5 repositórios e publicar as imagens Docker no ECR.
Depois de publicar, use `scripts/render-k8s-manifests.sh` para renderizar os deployments.

## 7) Ingress/rotas para o demo

Os Ingress do repo foram ajustados para encaminhar paths corretamente:

- `GET/POST /auth/admin/keys` e `/auth/validate` -> `auth-service`
- `/flags` -> `flag-service`
- `/targeting/rules/...` -> `targeting-service`
- `/evaluation/evaluate?...` e `/evaluation/health` -> `evaluation-service`

Na demonstração, use a URL do Load Balancer criada pelo `ingress-nginx`.


# ToggleMaster — Tech Challenge Fase 3 (POSTECH)

Este repositório reúne o que o enunciado pede: **Terraform (IaC)**, **pipelines GitHub Actions com DevSecOps**, **manifestos GitOps** e **base para ArgoCD** no EKS.

## Estrutura

| Pasta | Conteúdo |
|--------|-----------|
| `terraform/` | VPC, EKS (com **LabRole** para AWS Academy), 3× RDS PostgreSQL, ElastiCache Redis, DynamoDB `ToggleMasterAnalytics`, SQS, 5× ECR, ArgoCD via Helm |
| `gitops/` | Deployments/Services por microsserviço + `argocd/` com Applications |
| `services/` | **Go:** `auth`, `evaluation`. **Python (FastAPI):** `flag`, `targeting`, `analytics`. |
| `.github/workflows/` | Um `ci-<serviço>.yml` por microsserviço + `reusable-go-microservice.yml` e `reusable-python-microservice.yml`. |

**IDE / validação de workflows:** o caminho `uses: ./.github/workflows/...` é resolvido a partir da **raiz do repositório Git**. Abra a pasta **`challenge 3`** como raiz do workspace no Cursor (ou mantenha este projeto como repositório Git isolado), se você também tiver um Git na pasta pai (ex.: `Estudos`).

Para **mudar** qual serviço é Go ou Python, edite o `uses:` em `.github/workflows/ci-<nome>.yml` (reusable Go vs Python) e o conteúdo de `services/<nome>/`.

## AWS Academy (Opção A)

- Mantenha `use_lab_role = true` e `lab_role_name = "LabRole"` no `terraform.tfvars`.
- **Não** crie roles/policies IAM pelo Terraform; o EKS e o Node Group usam a mesma role referenciada por *data source*.

Conta pessoal: defina `use_lab_role = false` e implemente criação de roles (fora do escopo deste template mínimo).

## Backend remoto (S3)

1. Crie um bucket S3 (versionamento recomendado) na mesma conta.
2. Copie `terraform/backend.hcl.example` para `terraform/backend.hcl` e ajuste `bucket` e `region`.
3. Na pasta `terraform/`:

```bash
terraform init -backend-config backend.hcl -reconfigure
```

Terraform **1.10+**: você pode habilitar `use_lockfile = true` no backend (conforme aula).

## Variáveis sensíveis

Use `terraform.tfvars` (não commitado) a partir de `terraform/terraform.tfvars.example`, ou:

```bash
export TF_VAR_db_password="sua_senha_forte"
```

## Ordem sugerida de `apply`

1. Primeira subida (se o provider Kubernetes reclamar antes do cluster existir):  
   `terraform apply -target=module.vpc -target=module.eks -target=module.security_groups`  
   depois `terraform apply` completo.
2. Com `enable_argocd = true`, o Helm instala o ArgoCD no namespace `argocd`.

## ArgoCD e GitOps

1. Ajuste `repoURL` em todos os arquivos em `gitops/argocd/application-*.yaml` para o **seu** repositório (monorepo com pasta `gitops/` ou repo dedicado).
2. Obtenha a senha admin inicial:

```bash
aws eks update-kubeconfig --name togglemaster-dev-eks --region us-east-1
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

3. Aplique os Applications (com o chart já instalado pelo Terraform):

```bash
kubectl apply -f gitops/namespaces/togglemaster.yaml
kubectl apply -f gitops/argocd/
```

4. (Opcional) Se o repositório for privado, cadastre credenciais no ArgoCD (`argocd repo add ...`).

## GitHub Actions — secrets

No repositório GitHub, configure:

- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` (normalmente obrigatório na AWS Academy)

O job de **push na `main`** faz login no ECR, envia a imagem com tag `SHA do commit` e atualiza o campo `image` no manifesto GitOps correspondente, depois faz **commit + push** (exige permissão de escrita no repo).

## Segurança (credenciais de banco)

O enunciado exige abandonar senhas em arquivo texto: em produção use **AWS Secrets Manager** ou **SSM Parameter Store** + **External Secrets Operator** (ou CSI driver) e referencie apenas *keys* nos Deployments. O Terraform aqui ainda recebe `db_password` por variável para viabilizar o laboratório; evolua para `random_password` + Secrets Manager conforme orientação do professor.

## Entrega (PDF do desafio)

- Grave o vídeo (plan/apply, pipeline falhando/passando em segurança, bump GitOps, sync ArgoCD).
- Preencha o relatório (participantes, links, desafios, print do **AWS Pricing Calculator** ou Cost Explorer).

Use o modelo em `relatorio_entrega_template.txt`.

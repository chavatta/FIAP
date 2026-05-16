# Kubernetes — ordem e pré-requisitos

## Problemas corrigidos nos manifestos

- **targeting `service-targeting.yml`**: typo `iapiVersion` → `apiVersion` (impedia aplicar o Service).
- **auth**: `DATABASE_URL` com `$(VAR)` **não é expandido** pelo Kubernetes — use URL completa no Secret.
- **auth `secret-auth`**: valores em `stringData` devem ser **texto claro**, não base64.
- **auth Deployment**: bloco `resources` duplicado removido.
- **flag / targeting**: portas **8002 / 8003** (alinhadas ao Dockerfile), **`FLAG_DATABASE_URL`**, **`TARGETING_DATABASE_URL`**, **`AUTH_SERVICE_URL`** entre namespaces.
- **evaluation**: removidas variáveis Postgres inexistentes no app; adicionados **Redis**, **FLAG/TARGETING URLs**, **`SERVICE_API_KEY`**, portas **8004**.

## Ordem sugerida de apply

0. (Imagens no ECR) Preencha `.env` com variáveis `RDS_*`, `ELASTICACHE_ENDPOINT`, `SQS_QUEUE_URL`, `SERVICE_API_KEY`, etc. Rode `scripts/render-k8s-manifests.sh` (`envsubst` substitui `${...}` nos YAML). Aplique o que estiver em `k8s-rendered/`, não os templates crus em `*-service/k8s/`.
Detalhes: Para provisionar o cluster e dependencias do HPA/Ingress (metrics-server + ingress-nginx), use `docs/EKS-OpA-100-PDF.md`.

1. Namespaces (`namespace-*.yml`).
2. Postgres por serviço (Helm/bitnami ou manifestos próprios). Ajuste hosts nos Secrets:
   - `auth`: `DATABASE_URL` em `secret-auth.yml`
   - `flag`: `FLAG_DATABASE_URL` em `secret-flag.yml` (valores via `.env` + render)
   - `targeting`: `TARGETING_DATABASE_URL` em `secret-targeting.yml`
3. **evaluation**: (Academy/PDF) provisione e use **ElastiCache Redis**; depois aplique ConfigMap/Secret/Deployment do evaluation.
   - O `redis-evaluation.yml` fica apenas como opcao (debug local) e nao deve ser necessario no cenario com ElastiCache.
4. **evaluation** `secret-evaluation.yml`: defina **`SERVICE_API_KEY`** com chave válida do auth (`POST /admin/keys`).
5. Demais Deployments, Services, Ingress, HPA.

## DNS entre namespaces

Use FQDN: `http://<service>.<namespace>.svc.cluster.local` (ex.: auth em `auth-service.auth.svc.cluster.local`).

## Analytics

Precisa de **AWS** (SQS + DynamoDB). No modo **AWS Academy (LabRole)**, pods devem usar a role da instancia (nao setar AWS_ACCESS_KEY_ID/SECRET no Secret).
   - Preencha `analytics-config` com `AWS_SQS_URL` e `AWS_DYNAMODB_TABLE` (e mantenha `analytics-secrets` vazio).
   - Preencha `evaluation-config` com `AWS_SQS_URL` (mesma fila que o analytics consome).

# Kubernetes — ordem e pré-requisitos

## Problemas corrigidos nos manifestos

- **targeting `service-targeting.yml`**: typo `iapiVersion` → `apiVersion` (impedia aplicar o Service).
- **auth**: `DATABASE_URL` com `$(VAR)` **não é expandido** pelo Kubernetes — use URL completa no Secret.
- **auth `secret-auth`**: valores em `stringData` devem ser **texto claro**, não base64.
- **auth Deployment**: bloco `resources` duplicado removido.
- **flag / targeting**: portas **8002 / 8003** (alinhadas ao Dockerfile), **`FLAG_DATABASE_URL`**, **`TARGETING_DATABASE_URL`**, **`AUTH_SERVICE_URL`** entre namespaces.
- **evaluation**: removidas variáveis Postgres inexistentes no app; adicionados **Redis**, **FLAG/TARGETING URLs**, **`SERVICE_API_KEY`**, portas **8004**.

## Ordem sugerida de apply

1. Namespaces (`namespace-*.yml`).
2. Postgres por serviço (Helm/bitnami ou manifestos próprios). Ajuste hosts nos Secrets:
   - `auth`: `DATABASE_URL` em `secret-auth.yml`
   - `flag`: `FLAG_DATABASE_URL` em `secret-flag.yml` (ex.: `postgres-flag.flag.svc.cluster.local`)
   - `targeting`: `TARGETING_DATABASE_URL` em `secret-targeting.yml`
3. **evaluation**: `redis-evaluation.yml` → depois ConfigMap/Secret/Deployment do evaluation.
4. **evaluation** `secret-evaluation.yml`: defina **`SERVICE_API_KEY`** com chave válida do auth (`POST /admin/keys`).
5. Demais Deployments, Services, Ingress, HPA.

## DNS entre namespaces

Use FQDN: `http://<service>.<namespace>.svc.cluster.local` (ex.: auth em `auth-service.auth.svc.cluster.local`).

## Analytics

Precisa de **AWS** (SQS + DynamoDB). Em EKS prefira **IRSA** (ServiceAccount + role) em vez de chaves no Secret; preencha `analytics-config` e remova/ajuste `analytics-secrets` conforme o provedor.

# FIAP — Tech Challenge Fase 2

Repositório das aplicações conteinerizadas do Challenge Fase 2: 5 microsserviços (auth, flag, targeting, evaluation, analytics) com Docker, Kubernetes e AWS.

## Arquitetura

| Serviço          | Porta | Stack                    | Dependências              |
|------------------|-------|--------------------------|---------------------------|
| auth-service     | 8001  | Go, PostgreSQL           | auth-flag-db              |
| flag-service     | 8002  | Python, PostgreSQL       | auth-flag-db, auth        |
| targeting-service| 8003  | Python, PostgreSQL       | targeting-service-db, auth|
| evaluation-service| 8004 | Go, Redis, SQS           | redis, flag, targeting    |
| analytics-service| 8005  | Python, DynamoDB, SQS    | dynamodb-local            |

---

## Pré-requisitos

- **Docker** >= 29.3.0
- **Docker Compose** >= 5.1.0
- **Make** >= 4.3 (opcional no Windows)
- **Python** >= 3.11
- **Go** >= 1.22.2
- **AWS CLI** >= 2.x (para `make push` / ECR)

---

## Quick Start (stack local)

1. **Clonar e configurar**
   ```sh
   git clone https://github.com/chavatta/FIAP.git
   cd FIAP
   cp .env.example .env
   ```

2. **Build das imagens**
   ```sh
   make build
   ```
   Ou, sem Make: `docker build -t auth-service:v1 ./auth-service/` (e demais serviços).

3. **Subir a stack**
   ```sh
   docker-compose up -d
   ```

4. **Gerar chave API e criar flag/regra**
   ```sh
   # Criar chave
   curl -sS -X POST http://localhost:8001/admin/keys \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer admin-secreto-123" \
     -d '{"name":"evaluation-service"}'
   ```
   Copie o valor de `key`, coloque em `SERVICE_API_KEY` no `.env`, reinicie:
   ```sh
   docker-compose restart evaluation-service
   ```
   Depois crie a flag e a regra:
   ```sh
   KEY="sua_key_aqui"
   curl -sS -X POST http://localhost:8002/flags -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" -d '{"name":"enable-new-dashboard","description":"demo","is_enabled":true}'
   curl -sS -X POST http://localhost:8003/rules -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" -d '{"flag_name":"enable-new-dashboard","is_enabled":true,"rules":{"type":"PERCENTAGE","value":50}}'
   ```

5. **Testar avaliação**
   ```sh
   curl -sS "http://localhost:8004/evaluate?user_id=user-123&flag_name=enable-new-dashboard"; echo
   ```

---

## Make

| Comando     | Descrição                                      |
|------------|-------------------------------------------------|
| `make build` | Build de todas as imagens                      |
| `make push`  | Push para AWS ECR (requer `.env` com ECR URLs) |
| `make clean` | Remove imagens geradas                         |
| `make help`  | Lista comandos disponíveis                     |

---

## Docker Compose

```sh
docker-compose up -d      # Subir
docker-compose down       # Parar
docker-compose down -v    # Parar e remover volumes
docker-compose logs -f    # Ver logs
```

**9 contêineres:** 5 apps + 2 PostgreSQL + Redis + DynamoDB Local.

Antes de rodar, crie `.env` a partir de `.env.example`.

---

## Checklist (stack local)

- [ ] Criar `.env` a partir de `.env.example`
- [ ] Gerar `SERVICE_API_KEY` via `POST /admin/keys` (auth-service) e colocar no `.env`
- [ ] Reiniciar `evaluation-service` após alterar o `.env`
- [ ] Criar flag e regra antes de chamar `/evaluate`
- [ ] `AWS_SQS_URL` pode ficar vazio no demo local (DynamoDB Local é usado)

**Erro "Erro interno ao avaliar a flag"?** Verifique `SERVICE_API_KEY`, crie a flag/regra e confira os logs: `docker-compose logs evaluation-service`.

---

## Kubernetes (EKS)

Para deploy na nuvem:

1. Provisione EKS, ECR, RDS, ElastiCache, DynamoDB, SQS (ver `docs/AWS-ACADEMY-EKS-GUIA-COMPLETO.md`)
2. Preencha `.env.eks.example` → `.env`
3. Rode `scripts/render-k8s-manifests.sh` e aplique os manifests em `k8s-rendered/`
4. Instale `metrics-server` e `ingress-nginx` no cluster

Ver `k8s/README.md` para detalhes.

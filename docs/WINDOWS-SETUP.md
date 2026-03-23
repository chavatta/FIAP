# Rodar o ambiente no Windows

Guia para subir a stack local (Docker Compose) no Windows.

---

## 1. Pré-requisitos

| Requisito | Onde obter |
|-----------|------------|
| **Docker Desktop** | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) |
| **Git** (opcional) | Para clonar o repo e ter `make` via Git Bash |
| **WSL2** (recomendado) | Docker Desktop usa WSL2 por padrão — ative nas configurações |

> **Make:** O projeto usa Makefile, mas no Windows você pode usar os comandos Docker diretamente (veja seção 4).

---

## 2. Obter o projeto

**Opção A — Git:**
```powershell
git clone https://github.com/chavatta/FIAP.git
cd FIAP
```

**Opção B — Copiar a pasta** do iCloud/OneDrive ou do macOS.

---

## 3. Configurar o `.env`

1. Na pasta raiz do projeto, copie o exemplo:
   ```powershell
   Copy-Item .env.example .env
   ```

2. Edite o `.env` (Notepad, VS Code, etc.). Para o **demo local**, você pode deixar assim:
   - `AWS_SQS_URL` — comente a linha ou deixe vazia (`AWS_SQS_URL=`).
   - `SERVICE_API_KEY` — será preenchido no passo 5.

3. Evite conflitos com variáveis do sistema:
   ```powershell
   Remove-Item Env:AWS_SQS_URL -ErrorAction SilentlyContinue
   Remove-Item Env:FLAG_POSTGRES_DB -ErrorAction SilentlyContinue
   ```

---

## 4. Build das imagens Docker

Se não tiver `make`, use os comandos diretos no PowerShell (na pasta do projeto):

```powershell
# Build de todas as imagens
docker build --tag=auth-service:v1 ./auth-service/
docker build --tag=flag-service:v1 ./flag-service/
docker build --tag=targeting-service:v1 ./targeting-service/
docker build --tag=evaluation-service:v1 ./evaluation-service/
docker build --tag=analytics-service:v1 ./analytics-service/
```

Ou, se tiver **Make** (Git Bash / WSL):

```bash
make build
```

---

## 5. Subir os containers

```powershell
docker compose up -d
```

> Se der erro com `docker compose`, tente `docker-compose up -d` (versão antiga do Docker).

---

## 6. Gerar a SERVICE_API_KEY

O `evaluation-service` precisa de uma chave criada pelo `auth-service`:

1. Aguarde os serviços subirem (30–60 s).
2. Gere a chave:
   ```powershell
   curl -X POST http://localhost:8001/admin/keys `
     -H "Authorization: Bearer admin-secreto-123" `
     -H "Content-Type: application/json" `
     -d '{\"name\":\"eval-key\"}'
   ```
3. Copie o valor de `key` da resposta (ex.: `tm_key_01f9ad48...`).
4. Edite o `.env` e coloque:
   ```env
   SERVICE_API_KEY=tm_key_01f9ad48...
   ```
5. Reinicie o evaluation:
   ```powershell
   docker compose restart evaluation-service
   ```

---

## 7. Validar

```powershell
# Health dos serviços
curl http://localhost:8001/health
curl http://localhost:8002/flags
curl http://localhost:8003/rules
curl http://localhost:8004/health
curl http://localhost:8005/health
```

---

## 8. Comandos úteis

| Ação | Comando |
|------|---------|
| Ver logs | `docker compose logs -f` |
| Parar | `docker compose down` |
| Parar e remover volumes | `docker compose down -v` |
| Reiniciar um serviço | `docker compose restart <nome-servico>` |

---

## Troubleshooting

### "required variable FLAG_POSTGRES_DB / AWS_SQS_URL"
O `docker-compose.yml` pode estar desatualizado. Veja `docs/WINDOWS-COMPOSE-FIX.md`.

### Portas em uso
Altere no `.env`: `AUTH_PORT`, `FLAG_PORT`, etc., para portas livres (ex.: 9001, 9002…).

### Docker não inicia
- Verifique se a virtualização está ativada na BIOS.
- Use WSL2 no Docker Desktop (Settings → General).

### Caminho com espaços
Evite pastas como `C:\Fase 2\FIAP`; prefira `C:\Projetos\FIAP`.

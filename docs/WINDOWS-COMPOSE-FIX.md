# Correção: erros no Windows (FLAG_POSTGRES_DB, AWS_SQS_URL)

Se você vê estes erros ao rodar `docker-compose up` no Windows:

```
required variable FLAG_POSTGRES_DB is missing a value
required variable AWS_SQS_URL is missing a value
```

**Causa:** O projeto no Windows está com uma versão antiga do `docker-compose.yml`.

---

## Solução recomendada: usar a versão atual

1. Sincronize o projeto (git pull ou copie da pasta mais recente).
2. O `docker-compose.yml` atual usa:
   - `auth-flag-db` (um único Postgres para auth + flag) → variável `AUTH_POSTGRES_DB`
   - `AWS_SQS_URL` opcional (sintaxe `${AWS_SQS_URL:-}`)

3. Copie `.env.example` → `.env` e preencha. O `AWS_SQS_URL` pode ficar comentado ou vazio:
   ```env
   # AWS_SQS_URL=
   ```

---

## Se não puder atualizar agora (versão antiga)

Se ainda estiver com `flag-service-db` e `FLAG_POSTGRES_DB`:

1. **No `.env`**, adicione:
   ```env
   FLAG_POSTGRES_DB=flag_db
   ```

2. **Para `AWS_SQS_URL`**: o compose antigo pode usar `${AWS_SQS_URL:?}`, que exige valor. Opções:
   - Edite o `docker-compose.yml` e troque `${AWS_SQS_URL:?}` por `${AWS_SQS_URL:-}` nos serviços `evaluation-service` e `analytics-service`.
   - Ou defina um placeholder: `AWS_SQS_URL=opcional` (o app trata string vazia/nula).

---

## Variáveis do ambiente no Windows

O Docker Compose no Windows usa primeiro as variáveis do sistema/sessão e depois o `.env`. Se algo ainda falhar:

```powershell
# Remover variáveis conflitantes da sessão atual
Remove-Item Env:AWS_SQS_URL -ErrorAction SilentlyContinue
Remove-Item Env:FLAG_POSTGRES_DB -ErrorAction SilentlyContinue
```

Depois rode `docker-compose up -d` em uma nova sessão do PowerShell.

# Roteiro do vídeo de demo (até 20 min) — Tech Challenge Fase 2

**Modo:** Opção A — AWS Academy / `LabRole` (HPA por CPU, sem KEDA).

Objetivo do vídeo:

- Provar `docker-compose up` local com **9 contêineres** (5 apps + 4 dependências locais).
- Provar cluster Kubernetes na nuvem com **5 microsserviços** como Pods.
- Provar **Nginx Ingress** funcionando (curl/Postman na URL do Load Balancer).
- Provar escalabilidade (HPA no `evaluation-service` e no `analytics-service`).
- Provar dados no **DynamoDB** vindos do `analytics-service`.

---

## Parte 0 — Abertura (0:00–0:30)

- Mostrar rapidamente o enunciado/entregáveis.
- Explicar o que será mostrado:
  - Docker Compose local
  - EKS + Ingress
  - HPA (evaluation + analytics)
  - DynamoDB

---

## Parte 1 — Demo local (Docker Compose) (0:30–7:00)

### 1) Mostrar estrutura do repo (0:30–1:00)

Na raiz:

- `docker-compose.yml`
- `.env` (não mostrar dados sensíveis)
- `Makefile` (build/push)
- `k8s/README.md` (ordem de apply)

### 2) Subir stack local e provar 9 containers (1:00–3:00)

```powershell
docker-compose down -v
docker-compose up -d
docker-compose ps
```

Ponto de fala:

- Confirmar na tela: **9 contêineres** (5 apps + 2 Postgres + Redis + DynamoDB Local).

### 3) Provar health dos serviços (3:00–4:00)

```powershell
Invoke-WebRequest -Uri http://localhost:8001/health -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest -Uri http://localhost:8002/health -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest -Uri http://localhost:8003/health -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest -Uri http://localhost:8004/health -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest -Uri http://localhost:8005/health -UseBasicParsing | Select-Object -ExpandProperty Content
```

### 4) Fluxo completo (Auth → Flag/Targeting → Evaluation) (4:00–7:00)

1) Criar API key no `auth-service`:

```powershell
Invoke-WebRequest -Uri http://localhost:8001/admin/keys -Method POST -Headers @{"Content-Type"="application/json"; "Authorization"="Bearer admin-secreto-123"} -Body '{"name":"evaluation-service"}' -UseBasicParsing | Select-Object -ExpandProperty Content
```

2) Copiar o campo `key` e setar no terminal:

```powershell
$KEY = "COLE_AQUI_A_KEY"
```

3) Criar flag:

```powershell
Invoke-WebRequest -Uri http://localhost:8002/flags -Method POST -Headers @{"Content-Type"="application/json"; "Authorization"="Bearer $KEY"} -Body '{"name":"enable-new-dashboard","description":"demo pdf","is_enabled":true}' -UseBasicParsing | Select-Object -ExpandProperty Content
```

4) Criar regra (50%):

```powershell
Invoke-WebRequest -Uri http://localhost:8003/rules -Method POST -Headers @{"Content-Type"="application/json"; "Authorization"="Bearer $KEY"} -Body '{"flag_name":"enable-new-dashboard","is_enabled":true,"rules":{"type":"PERCENTAGE","value":50}}' -UseBasicParsing | Select-Object -ExpandProperty Content
```

5) Chamar evaluate (true/false):

```powershell
Invoke-WebRequest -Uri "http://localhost:8004/evaluate?user_id=user-123&flag_name=enable-new-dashboard" -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest -Uri "http://localhost:8004/evaluate?user_id=user-abc&flag_name=enable-new-dashboard" -UseBasicParsing | Select-Object -ExpandProperty Content
```

Ponto de fala:

- `evaluation-service` é o hot-path, usa Redis (cache) e consulta `flag-service` e `targeting-service`.

**Se aparecer `{"error":"Erro interno ao avaliar a flag"}`:**

1. Verifique se criou a flag e a regra (passos 3 e 4) **usando a mesma KEY**.
2. O `SERVICE_API_KEY` no `.env` **deve ser a key retornada** no passo 1. Se alterou o `.env`, reinicie: `docker-compose restart evaluation-service`.
3. Verifique logs: `docker-compose logs evaluation-service` — o erro real aparece lá (ex.: "flag-service retornou status 401" = chave inválida).

---

## Parte 2 — Nuvem (EKS) (7:00–16:00)

### 5) Mostrar cluster EKS provisionado (7:00–8:00)

No AWS Console:

- EKS cluster `ACTIVE`
- Managed node group com autoscaling (Min/Desejado/Max) e uso de `LabRole`

### 6) Mostrar recursos AWS (8:00–10:00)

No AWS Console, mostrar:

- **ECR**: 5 repositórios (um por microsserviço)
- **RDS**: 3 instâncias Postgres (auth/flag/targeting)
- **ElastiCache**: 1 cluster Redis (evaluation)
- **SQS**: 1 fila (evaluation produz, analytics consome)
- **DynamoDB**: tabela `ToggleMasterAnalytics` (`event_id` como PK)

### 7) Mostrar pods rodando (10:00–12:00)

No terminal com `kubectl` configurado:

```powershell
kubectl get pods -A
kubectl get pods -n auth
kubectl get pods -n flag
kubectl get pods -n targeting
kubectl get pods -n evaluation
kubectl get pods -n analytics
```

### 8) Mostrar Ingress e chamada externa (12:00–16:00)

1) Mostrar Service do controller:

```powershell
kubectl get svc -n ingress-nginx
```

2) Mostrar Ingress:

```powershell
kubectl get ingress -A
```

3) Copiar o DNS/IP do Load Balancer e testar:

```powershell
$LB = "http://ab30b59d003074c8caf2fe1cb93f3a4b-66409170b442619e.elb.us-east-1.amazonaws.com"

Invoke-WebRequest -Uri "$LB/auth/health" -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest -Uri "$LB/flags/health" -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest -Uri "$LB/targeting/health" -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest -Uri "$LB/evaluation/health" -UseBasicParsing | Select-Object -ExpandProperty Content
```

Opcional: fazer 1 chamada real no evaluate via LB (se já tiver flag/rule no RDS).

---

## Parte 3 — Escalabilidade (HPA) (16:00–19:30)

### 9) Mostrar HPAs (16:00–16:30)

```powershell
kubectl get hpa -A
kubectl get hpa -n evaluation
kubectl get hpa -n analytics
```

### 10) Carga no evaluation-service (16:30–18:00)

Em um terminal:

```powershell
while ($true) { kubectl get hpa -n evaluation; Start-Sleep 2 }
```

Em outro terminal, gerar carga:

```powershell
# Preferido: use o script do repo (use WSL para bash)
wsl bash scripts/stress-test-evaluation.sh --lb "$LB" --duration 60s --concurrency 50

# Alternativa (se quiser rodar direto):
# hey -z 60s -c 50 "$LB/evaluation/evaluate?user_id=user-123&flag_name=enable-new-dashboard"
```

Mostrar replicas subindo (`kubectl get pods -n evaluation`).

### 11) Analytics: SQS → CPU → HPA (18:00–19:00)

- Enviar várias mensagens para a fila (mesmo payload do evaluation): no **PowerShell** (Windows) `.\scripts\send-sqs-evaluation-events.ps1 -Count 200` com `$env:AWS_SQS_URL` e `$env:AWS_REGION` definidos; no **CloudShell/WSL**, `./scripts/send-sqs-evaluation-events.sh --count 200`. Alternativa: console SQS (Send message).
- Em terminal:

```powershell
while ($true) { kubectl get hpa -n analytics; Start-Sleep 2 }
while ($true) { kubectl get pods -n analytics; Start-Sleep 2 }
```

### 12) Provar dados no DynamoDB (19:00–19:30)

No console DynamoDB:

- Tabela `ToggleMasterAnalytics`
- Mostrar itens aparecendo (vindos do worker)

---

## Fechamento (19:30–20:00)

- Recapitular:
  - Compose local OK
  - Pods no EKS OK
  - Ingress OK
  - HPA evaluation OK
  - HPA analytics OK
  - DynamoDB OK
- Explicar rapidamente propósito dos datastores:
  - **RDS** (relacional / transacional)
  - **ElastiCache** (cache / baixa latência)
  - **DynamoDB** (NoSQL / eventos / alta escala)


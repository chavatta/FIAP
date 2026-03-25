#!/usr/bin/env bash
set -euo pipefail

# Stress pesado no evaluation-service para tentar passar do target do HPA (CPU 70%).
# O HPA em evaluation-service/k8s/HPA-evaluation.yml usa só métrica de CPU; memória
# pode subir no pod mas não dispara réplicas até você acrescentar métrica de memory no HPA.
#
# Em outro terminal: kubectl get hpa -n evaluation -w
#                    kubectl get pods -n evaluation -w
#
# Exemplos:
#   ./scripts/stress-test-evaluation-heavy.sh --lb http://SEU-ELB
#   ./scripts/stress-test-evaluation-heavy.sh --local --workers 6 --concurrency 150
#   ./scripts/stress-test-evaluation-heavy.sh --url "http://..." --requests 80000

BASE_URL=""
FULL_URL=""
DURATION="5m"
CONCURRENCY="200"
REQUESTS_PER_WORKER="40000"
WORKERS="4"
USER_ID="user-123"
FLAG_NAME="enable-new-dashboard"

usage() {
  cat <<'EOF'
Uso:
  ./scripts/stress-test-evaluation-heavy.sh --local
  ./scripts/stress-test-evaluation-heavy.sh --lb http://HOST_OU_SÓ_HOSTNAME
  ./scripts/stress-test-evaluation-heavy.sh --url "http://.../evaluation/evaluate?..."

Opções (defaults pensados para forçar CPU sustentada alguns minutos):
  --concurrency <n>     Concorrência por worker ab (default: 200; hey usa este valor)
  --duration <dur>      Só hey: duração (default: 5m)
  --requests <n>      Só ab: requests por worker (default: 40000)
  --workers <n>       Só ab: processos ab em paralelo (default: 4)
  --user-id / --flag-name   Igual ao script leve

IMPORTANTE — --lb:
  • Só a URL BASE do Load Balancer (ex.: http://xxx.elb.us-east-1.amazonaws.com).
  • NÃO cole comando "ab" nem o path /evaluation/... (o script monta o path).
  • Uma linha, aspas simples por fora se preferir: --lb 'http://SEU-ELB'

Observação: com ab, carga total ≈ workers × concorrência conexões simultâneas (picos).
  Se não houver hey/ab, o script usa curl em loop (comum no Git Bash no Windows).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --local)
      BASE_URL="http://localhost:8004"
      shift
      ;;
    --lb)
      BASE_URL="${2:-}"
      if [[ "$BASE_URL" =~ [[:space:]] ]]; then
        echo "Erro: --lb não pode ter espaços nem comando 'ab'. Use só a base, ex.:" >&2
        echo '  --lb "http://xxxx.elb.us-east-1.amazonaws.com"' >&2
        exit 1
      fi
      case "$BASE_URL" in
        *"ab "*|*" ab"*|*-n\ *|*-c\ *)
          echo "Erro: --lb não é um comando ab; é só o host do ELB (http://...amazonaws.com)." >&2
          exit 1
          ;;
      esac
      shift 2
      ;;
    --url)
      FULL_URL="${2:-}"
      shift 2
      ;;
    --duration)
      DURATION="${2:-}"
      shift 2
      ;;
    --concurrency)
      CONCURRENCY="${2:-}"
      shift 2
      ;;
    --requests)
      REQUESTS_PER_WORKER="${2:-}"
      shift 2
      ;;
    --workers)
      WORKERS="${2:-}"
      shift 2
      ;;
    --user-id)
      USER_ID="${2:-}"
      shift 2
      ;;
    --flag-name)
      FLAG_NAME="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Argumento desconhecido: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$FULL_URL" ]; then
  if [ -z "$BASE_URL" ]; then
    echo "Erro: informe --local, --lb ou --url." >&2
    usage
    exit 1
  fi
  if [[ "$BASE_URL" != http://* ]] && [[ "$BASE_URL" != https://* ]]; then
    BASE_URL="http://${BASE_URL}"
  fi
  if [[ "$BASE_URL" == http*://localhost* ]]; then
    FULL_URL="${BASE_URL}/evaluate?user_id=${USER_ID}&flag_name=${FLAG_NAME}"
  else
    FULL_URL="${BASE_URL}/evaluation/evaluate?user_id=${USER_ID}&flag_name=${FLAG_NAME}"
  fi
fi

echo "URL: $FULL_URL"
echo "Modo hey: duração=$DURATION concorrência=$CONCURRENCY"
echo "Modo ab:  workers=$WORKERS requests/worker=$REQUESTS_PER_WORKER concorrência/worker=$CONCURRENCY"
echo
echo "Acompanhe: kubectl get hpa -n evaluation -w"
echo

run_hey() {
  echo "Rodando hey (carga contínua)..."
  hey -z "$DURATION" -c "$CONCURRENCY" "$FULL_URL"
}

run_ab_parallel() {
  echo "Rodando $WORKERS× ab em paralelo..."
  local i
  for i in $(seq 1 "$WORKERS"); do
    ab -n "$REQUESTS_PER_WORKER" -c "$CONCURRENCY" -q "$FULL_URL" &
  done
  wait
  echo "Todos os workers ab terminaram."
}

# Fallback: Git Bash no Windows costuma ter curl, mas não ab/hey.
run_curl_flood() {
  local sec
  if [[ "$DURATION" =~ ^([0-9]+)m$ ]]; then
    sec=$((BASH_REMATCH[1] * 60))
  elif [[ "$DURATION" =~ ^([0-9]+)s$ ]]; then
    sec=${BASH_REMATCH[1]}
  else
    sec="${CURL_DURATION_SEC:-300}"
  fi
  echo "Modo curl (sem hey/ab): $WORKERS workers × até $CONCURRENCY curls paralelos por batelada, ${sec}s total."
  echo "Dica Windows: se travar, reduza --concurrency ou --workers."
  local pids=()
  local w
  for w in $(seq 1 "$WORKERS"); do
    (
      local deadline=$(( $(date +%s) + sec ))
      while [ "$(date +%s)" -lt "$deadline" ]; do
        local i
        for i in $(seq 1 "$CONCURRENCY"); do
          curl -sS -o /dev/null --connect-timeout 5 --max-time 90 "$FULL_URL" 2>/dev/null &
        done
        wait
      done
    ) &
    pids+=($!)
  done
  local pid
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  echo "curl flood concluído."
}

if command -v hey >/dev/null 2>&1; then
  run_hey
  exit 0
fi

if command -v ab >/dev/null 2>&1; then
  run_ab_parallel
  exit 0
fi

if command -v curl >/dev/null 2>&1; then
  run_curl_flood
  exit 0
fi

echo "Erro: instale hey, ab (ApacheBench) ou curl." >&2
echo "  CloudShell / Amazon Linux: sudo dnf install -y httpd-tools" >&2
echo "  Windows: WSL (sudo apt install apache2-utils) ou instale curl" >&2
exit 1

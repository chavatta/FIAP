#!/usr/bin/env bash
set -euo pipefail

# Stress test do evaluation-service (PDF Fase 2).
# Usa `hey` se disponível; caso contrário usa `ab` (ApacheBench).
#
# Exemplos:
#   ./scripts/stress-test-evaluation.sh --local
#   ./scripts/stress-test-evaluation.sh --lb http://SEU-LB-DNS
#   ./scripts/stress-test-evaluation.sh --url "http://localhost:8004/evaluate?user_id=user-123&flag_name=enable-new-dashboard"
#
# Opções:
#   --duration 60s     (hey) duração do teste (default: 60s)
#   --concurrency 50   (hey/ab) concorrência (default: 50)
#   --requests 5000    (ab) total de requests (default: 5000)
#   --user-id user-123
#   --flag-name enable-new-dashboard

BASE_URL=""
DURATION="60s"
CONCURRENCY="50"
REQUESTS="5000"
USER_ID="user-123"
FLAG_NAME="enable-new-dashboard"

usage() {
  cat <<'EOF'
Uso:
  ./scripts/stress-test-evaluation.sh --local
  ./scripts/stress-test-evaluation.sh --lb http://SEU-LB
  ./scripts/stress-test-evaluation.sh --url "http://.../evaluate?user_id=...&flag_name=..."

Opções:
  --local                  Usa http://localhost:8004
  --lb <base_url>          Base URL do LB (ex.: http://xxx.elb.amazonaws.com ou só o hostname — vira http://)
                           O script chama /evaluation/evaluate no LB.
  --url <url_completa>     URL completa do endpoint /evaluate (ignora --local/--lb)

  --duration <dur>         Duração do teste (hey). Default: 60s
  --concurrency <n>        Concorrência. Default: 50
  --requests <n>           Nº total de requests (ab). Default: 5000
  --user-id <id>           Default: user-123
  --flag-name <name>       Default: enable-new-dashboard

EOF
}

FULL_URL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --local)
      BASE_URL="http://localhost:8004"
      shift
      ;;
    --lb)
      BASE_URL="${2:-}"
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
      REQUESTS="${2:-}"
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

  # Hostname sozinho (ex.: xxx.elb.amazonaws.com) → prefixar http://
  if [[ "$BASE_URL" != http://* ]] && [[ "$BASE_URL" != https://* ]]; then
    BASE_URL="http://${BASE_URL}"
  fi

  # Se for LB, o path no Ingress é /evaluation/...
  if [[ "$BASE_URL" == http*://localhost* ]]; then
    FULL_URL="${BASE_URL}/evaluate?user_id=${USER_ID}&flag_name=${FLAG_NAME}"
  else
    FULL_URL="${BASE_URL}/evaluation/evaluate?user_id=${USER_ID}&flag_name=${FLAG_NAME}"
  fi
fi

echo "URL: $FULL_URL"
echo "Concorrência: $CONCURRENCY"
echo "Duração (hey): $DURATION"
echo "Requests (ab): $REQUESTS"
echo

if command -v hey >/dev/null 2>&1; then
  echo "Rodando com hey..."
  hey -z "$DURATION" -c "$CONCURRENCY" "$FULL_URL"
  exit 0
fi

if command -v ab >/dev/null 2>&1; then
  echo "Rodando com ab..."
  ab -n "$REQUESTS" -c "$CONCURRENCY" "$FULL_URL"
  exit 0
fi

echo "Erro: instale 'hey' ou 'ab' para rodar o stress test." >&2
echo "Dica (CloudShell / Amazon Linux):"
echo "  sudo dnf install -y httpd-tools   # fornece o ab (ApacheBench)"
echo "Dica (macOS):"
echo "  brew install hey"
echo "  # ou: brew install httpd"
exit 1


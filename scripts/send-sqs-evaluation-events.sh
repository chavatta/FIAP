#!/usr/bin/env bash
set -euo pipefail

# Envia eventos de avaliação para a fila SQS (mesmo JSON do evaluation-service → analytics).
# Requer AWS CLI autenticado e permissão sqs:SendMessage na fila.
#
# Exemplos:
#   export AWS_SQS_URL="https://sqs.us-east-1.amazonaws.com/123456789012/fiap-evaluation-events"
#   export AWS_REGION=us-east-1
#   ./scripts/send-sqs-evaluation-events.sh --count 200
#
#   ./scripts/send-sqs-evaluation-events.sh --queue-url "$AWS_SQS_URL" --count 50

QUEUE_URL="${SQS_QUEUE_URL:-${AWS_SQS_URL:-}}"
COUNT="100"
DELAY_MS="0"
USER_ID="user-123"
FLAG_NAME="enable-new-dashboard"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"

usage() {
  cat <<'EOF'
Uso:
  export AWS_SQS_URL="https://sqs.REGION.amazonaws.com/ACCOUNT/fila"
  ./scripts/send-sqs-evaluation-events.sh [--count N] [--delay-ms N]

Opções:
  --queue-url <url>   Fila SQS (default: SQS_QUEUE_URL ou AWS_SQS_URL)
  --count <n>         Quantidade de mensagens (default: 100)
  --delay-ms <n>      Pausa entre envios em ms (default: 0)
  --user-id <id>      Default: user-123
  --flag-name <name>  Default: enable-new-dashboard
  --region <r>        Default: AWS_REGION / AWS_DEFAULT_REGION

EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --queue-url)
      QUEUE_URL="${2:-}"
      shift 2
      ;;
    --count)
      COUNT="${2:-}"
      shift 2
      ;;
    --delay-ms)
      DELAY_MS="${2:-}"
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
    --region)
      REGION="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Opção desconhecida: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$QUEUE_URL" ]; then
  echo "Defina --queue-url ou as variáveis SQS_QUEUE_URL / AWS_SQS_URL." >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI não encontrado no PATH." >&2
  exit 1
fi

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -lt 1 ]; then
  echo "--count deve ser um inteiro >= 1." >&2
  exit 1
fi

aws_args=(--queue-url "$QUEUE_URL")
if [ -n "$REGION" ]; then
  aws_args+=(--region "$REGION")
fi

echo "Enviando $COUNT mensagem(ns) para a fila..."
i=1
while [ "$i" -le "$COUNT" ]; do
  # Alterna result para variar um pouco o payload (mesmo esquema do Go)
  if (( i % 2 == 0 )); then
    result="true"
  else
    result="false"
  fi
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  body="$(printf '{"user_id":"%s","flag_name":"%s","result":%s,"timestamp":"%s"}' \
    "$USER_ID" "$FLAG_NAME" "$result" "$ts")"

  aws sqs send-message "${aws_args[@]}" --message-body "$body" >/dev/null

  if [ "$DELAY_MS" -gt 0 ] 2>/dev/null; then
    # ms → sleep fraction (best effort)
    sleep "$(awk -v ms="$DELAY_MS" 'BEGIN { printf "%.3f", ms/1000 }')"
  fi
  i=$((i + 1))
done

echo "Concluído: $COUNT mensagem(ns) enviada(s)."

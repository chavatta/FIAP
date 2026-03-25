#!/usr/bin/env bash
set -euo pipefail

# Envia eventos de avaliação para a fila SQS (mesmo JSON do evaluation-service → analytics).
# Por padrão usa SendMessageBatch (até 10 msgs/chamada) para ser muito mais rápido.
# Requer AWS CLI autenticado e permissão sqs:SendMessage na fila.
#
# Exemplos:
#   export AWS_SQS_URL="https://sqs.us-east-1.amazonaws.com/123456789012/fiap-evaluation-events"
#   export AWS_REGION=us-east-1
#   ./scripts/send-sqs-evaluation-events.sh --count 200
#
#   ./scripts/send-sqs-evaluation-events.sh --queue-url "$AWS_SQS_URL" --count 50 --no-batch

QUEUE_URL="${SQS_QUEUE_URL:-${AWS_SQS_URL:-}}"
COUNT="100"
DELAY_MS="0"
USER_ID="user-123"
FLAG_NAME="enable-new-dashboard"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
BATCH_MODE=1
BATCH_SIZE=10

usage() {
  cat <<'EOF'
Uso:
  export AWS_SQS_URL="https://sqs.REGION.amazonaws.com/ACCOUNT/fila"
  ./scripts/send-sqs-evaluation-events.sh [--count N] [--delay-ms N]

Opções:
  --queue-url <url>   Fila SQS (default: SQS_QUEUE_URL ou AWS_SQS_URL)
  --count <n>         Quantidade de mensagens (default: 100)
  --delay-ms <n>      Pausa entre lotes ou entre envios (default: 0)
  --user-id <id>      Default: user-123
  --flag-name <name>  Default: enable-new-dashboard
  --region <r>        Default: AWS_REGION / AWS_DEFAULT_REGION
  --batch-size <n>    Msgs por SendMessageBatch, 1–10 (default: 10)
  --no-batch          Um SendMessage por mensagem (lento; só diagnóstico)

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
    --batch-size)
      BATCH_SIZE="${2:-}"
      shift 2
      ;;
    --no-batch)
      BATCH_MODE=0
      shift
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

if [ "$BATCH_MODE" -eq 1 ]; then
  if ! [[ "$BATCH_SIZE" =~ ^[0-9]+$ ]] || [ "$BATCH_SIZE" -lt 1 ] || [ "$BATCH_SIZE" -gt 10 ]; then
    echo "--batch-size deve estar entre 1 e 10 (limite SQS)." >&2
    exit 1
  fi
else
  BATCH_SIZE=1
fi

if ! [[ "$DELAY_MS" =~ ^[0-9]+$ ]]; then
  echo "--delay-ms deve ser um inteiro >= 0." >&2
  exit 1
fi

aws_args=(--queue-url "$QUEUE_URL")
if [ -n "$REGION" ]; then
  aws_args+=(--region "$REGION")
fi

# Gera JSON de Entries (array) para SendMessageBatch; índice inicial e quantidade via env.
batch_entries_json() {
  _SQS_BATCH_START="$1" _SQS_BATCH_SIZE="$2" _SQS_BATCH_USER="$USER_ID" _SQS_BATCH_FLAG="$FLAG_NAME" \
    python3 -c 'import json, os
from datetime import datetime, timezone
start, size = int(os.environ["_SQS_BATCH_START"]), int(os.environ["_SQS_BATCH_SIZE"])
uid, flag = os.environ["_SQS_BATCH_USER"], os.environ["_SQS_BATCH_FLAG"]
entries = []
for off in range(size):
    i = start + off
    r = (i % 2) == 0
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    body = {"user_id": uid, "flag_name": flag, "result": r, "timestamp": ts}
    entries.append({"Id": "b%d" % i, "MessageBody": json.dumps(body, separators=(",", ":"))})
print(json.dumps(entries))'
}

send_one_by_one() {
  local i=1
  while [ "$i" -le "$COUNT" ]; do
    if (( i % 2 == 0 )); then
      result="true"
    else
      result="false"
    fi
    ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    body="$(printf '{"user_id":"%s","flag_name":"%s","result":%s,"timestamp":"%s"}' \
      "$USER_ID" "$FLAG_NAME" "$result" "$ts")"
    aws sqs send-message "${aws_args[@]}" --message-body "$body" >/dev/null
    if [ "$DELAY_MS" -gt 0 ]; then
      sleep "$(awk -v ms="$DELAY_MS" 'BEGIN { printf "%.3f", ms/1000 }')"
    fi
    i=$((i + 1))
  done
}

send_in_batches() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 não encontrado; usando envio um a um." >&2
    send_one_by_one
    return
  fi
  local sent=0
  local start=1
  while [ "$sent" -lt "$COUNT" ]; do
    local remain=$((COUNT - sent))
    local this_batch="$BATCH_SIZE"
    if [ "$this_batch" -gt "$remain" ]; then
      this_batch="$remain"
    fi
    entries="$(batch_entries_json "$start" "$this_batch")"
    aws sqs send-message-batch "${aws_args[@]}" --entries "$entries" >/dev/null
    sent=$((sent + this_batch))
    start=$((start + this_batch))
    if [ "$DELAY_MS" -gt 0 ] && [ "$sent" -lt "$COUNT" ]; then
      sleep "$(awk -v ms="$DELAY_MS" 'BEGIN { printf "%.3f", ms/1000 }')"
    fi
  done
}

if [ "$BATCH_MODE" -eq 0 ]; then
  echo "Enviando $COUNT mensagem(ns) (um SendMessage por mensagem)..."
  send_one_by_one
else
  echo "Enviando $COUNT mensagem(ns) em lotes de até $BATCH_SIZE (SendMessageBatch)..."
  send_in_batches
fi

echo "Concluído: $COUNT mensagem(ns) enviada(s)."

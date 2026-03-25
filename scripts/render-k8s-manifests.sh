#!/usr/bin/env bash
set -euo pipefail

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst nao encontrado. Instale gettext, ex.:" >&2
  echo "  sudo dnf install -y gettext   # Amazon Linux 2023 / CloudShell" >&2
  echo "  sudo apt-get install -y gettext-envsubst   # Debian/Ubuntu" >&2
  exit 1
fi

# Render manifest templates using ${AWS_*} values from the project's .env.
# Why: Kubernetes does not interpolate env vars inside YAML, but the PDF requires
# that deployments reference images published to ECR.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="$ROOT_DIR/k8s-rendered"
mkdir -p "$OUT_DIR"

if [ -f "$ROOT_DIR/.env" ]; then
  # Export variables so envsubst can see them.
  set -a
  # shellcheck disable=SC1090
  source "$ROOT_DIR/.env"
  set +a
else
  echo "Aviso: .env nao encontrado na raiz. Execute render-k8s-manifests com as variaveis AWS_* no seu ambiente." >&2
fi

export AWS_REGION="${AWS_REGION:-us-east-1}"
export __SQS_QUEUE_URL__="${SQS_QUEUE_URL:-${AWS_SQS_URL:-}}"
export __ELASTICACHE_ENDPOINT__="${ELASTICACHE_ENDPOINT:-}"

export __RDS_AUTH_ENDPOINT__="${RDS_AUTH_ENDPOINT:-}"
export __RDS_AUTH_DB__="${RDS_AUTH_DB:-}"
export __RDS_AUTH_USER__="${RDS_AUTH_USER:-}"
export __RDS_AUTH_PASSWORD__="${RDS_AUTH_PASSWORD:-}"

export __RDS_FLAG_ENDPOINT__="${RDS_FLAG_ENDPOINT:-}"
export __RDS_FLAG_DB__="${RDS_FLAG_DB:-}"
export __RDS_FLAG_USER__="${RDS_FLAG_USER:-}"
export __RDS_FLAG_PASSWORD__="${RDS_FLAG_PASSWORD:-}"

export __RDS_TARGETING_ENDPOINT__="${RDS_TARGETING_ENDPOINT:-}"
export __RDS_TARGETING_DB__="${RDS_TARGETING_DB:-}"
export __RDS_TARGETING_USER__="${RDS_TARGETING_USER:-}"
export __RDS_TARGETING_PASSWORD__="${RDS_TARGETING_PASSWORD:-}"

export SERVICE_API_KEY="${SERVICE_API_KEY:-}"

SERVICES_DIRS=(
  "auth-service/k8s"
  "flag-service/k8s"
  "targeting-service/k8s"
  "evaluation-service/k8s"
  "analytics-service/k8s"
)

for dir in "${SERVICES_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  # Pastas do repo: auth-service/k8s → saída auth/ (igual a k8s-apply.sh e docs)
  service_repo="$(basename "$(dirname "$dir")")"
  out_name="${service_repo%-service}"
  mkdir -p "$OUT_DIR/$out_name"

  for file in "$dir"/*.yml; do
    [ -f "$file" ] || continue
    out_file="$OUT_DIR/$out_name/$(basename "$file")"
    envsubst < "$file" > "$out_file"
  done
done

echo "Manifests renderizados em: $OUT_DIR"


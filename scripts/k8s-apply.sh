#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f "$ROOT_DIR/.env" ]; then
  echo "Erro: .env nao encontrado na raiz. (Dica: copie .env.eks.example -> .env e preencha.)" >&2
  exit 1
fi

echo "Renderizando manifests (ECR/vars)..."
"$ROOT_DIR/scripts/render-k8s-manifests.sh" >/dev/null

echo "Aplicando namespaces..."
kubectl apply -f "$ROOT_DIR/k8s-rendered/auth/namespace-auth.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/flag/namespace-flag.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/targeting/namespace-targeting.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/evaluation/namespace-evaluation.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/analytics/namespace-analytics.yml"

echo "Aplicando Secrets/ConfigMaps..."
kubectl apply -f "$ROOT_DIR/k8s-rendered/auth/secret-auth.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/auth/configMap-auth.yml"

kubectl apply -f "$ROOT_DIR/k8s-rendered/flag/secret-flag.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/flag/configMap-flag.yml"

kubectl apply -f "$ROOT_DIR/k8s-rendered/targeting/secret-targeting.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/targeting/configMap-targeting.yml"

kubectl apply -f "$ROOT_DIR/k8s-rendered/evaluation/secret-evaluation.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/evaluation/configMap-evaluation.yml"

kubectl apply -f "$ROOT_DIR/k8s-rendered/analytics/secret-analytics.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/analytics/configMap-analytics.yml"

echo "Aplicando Deployments/Services..."
kubectl apply -f "$ROOT_DIR/k8s-rendered/auth/deployment-auth.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/auth/service-auth.yml"

kubectl apply -f "$ROOT_DIR/k8s-rendered/flag/deployment-flag.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/flag/service-flag.yml"

kubectl apply -f "$ROOT_DIR/k8s-rendered/targeting/deployment-targeting.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/targeting/service-targeting.yml"

kubectl apply -f "$ROOT_DIR/k8s-rendered/evaluation/deployment-evaluation.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/evaluation/service-evaluation.yml"

kubectl apply -f "$ROOT_DIR/k8s-rendered/analytics/deployment-analytics.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/analytics/service-analytics.yml"

echo "Aplicando Ingress..."
kubectl apply -f "$ROOT_DIR/k8s-rendered/auth/ingress-auth.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/flag/ingress-flag.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/targeting/ingress-targeting.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/evaluation/ingress-evaluation.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/analytics/ingress-analytics.yml"

echo "Aplicando HPA..."
kubectl apply -f "$ROOT_DIR/k8s-rendered/evaluation/HPA-evaluation.yml"
kubectl apply -f "$ROOT_DIR/k8s-rendered/analytics/HPA-analytics.yml"

echo "OK. Verifique:"
echo "  kubectl get pods -A"
echo "  kubectl get ingress -A"
echo "  kubectl get hpa -A"


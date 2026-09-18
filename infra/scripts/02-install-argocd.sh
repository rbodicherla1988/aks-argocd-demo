#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"

echo "==> Adding Argo Helm repo"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update argo >/dev/null

echo "==> Installing Argo CD into namespace $ARGOCD_NAMESPACE"
kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "$ARGOCD_RELEASE" argo/argo-cd \
  --namespace "$ARGOCD_NAMESPACE" \
  --set server.service.type=LoadBalancer \
  --wait \
  --timeout 10m

echo "==> Waiting for argocd-server LoadBalancer EXTERNAL-IP"
for i in $(seq 1 60); do
  EXTERNAL_IP="$(kubectl get svc "${ARGOCD_RELEASE}-server" -n "$ARGOCD_NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  if [[ -z "$EXTERNAL_IP" ]]; then
    EXTERNAL_IP="$(kubectl get svc "${ARGOCD_RELEASE}-server" -n "$ARGOCD_NAMESPACE" \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  fi
  if [[ -n "$EXTERNAL_IP" ]]; then
    break
  fi
  sleep 5
done

ADMIN_PW="$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)"

echo ""
echo "Argo CD installed."
echo "  UI:       https://${EXTERNAL_IP:-<pending>}"
echo "  Username: admin"
echo "  Password: $ADMIN_PW"
echo ""
echo "Note: learning setup uses LoadBalancer without TLS termination hardening."
echo "      Next step for production: Ingress + cert-manager."

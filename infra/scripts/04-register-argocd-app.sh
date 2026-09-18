#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"

if [[ -z "${GIT_REPO_URL}" ]]; then
  echo "GIT_REPO_URL is required." >&2
  echo "Example:" >&2
  echo "  GIT_REPO_URL=https://github.com/<you>/<repo>.git ./04-register-argocd-app.sh" >&2
  echo "Repo root must contain gitops/sample-web (this demo folder)." >&2
  exit 1
fi

APP_TEMPLATE="$DEMO_ROOT/gitops/argocd/application.yaml"
TMP_APP="$(mktemp)"
trap 'rm -f "$TMP_APP"' EXIT

# Substitute placeholders
sed \
  -e "s|GIT_REPO_URL|${GIT_REPO_URL}|g" \
  -e "s|targetRevision: HEAD|targetRevision: ${GIT_TARGET_REVISION}|g" \
  -e "s|path: gitops/sample-web|path: ${GITOPS_PATH}|g" \
  "$APP_TEMPLATE" > "$TMP_APP"

# Optional private repo credentials
if [[ -n "${GIT_PASSWORD}" ]]; then
  echo "==> Registering private git repo credentials with Argo CD"
  kubectl -n "$ARGOCD_NAMESPACE" create secret generic repo-sample-web \
    --from-literal=type=git \
    --from-literal=url="$GIT_REPO_URL" \
    --from-literal=username="${GIT_USERNAME:-git}" \
    --from-literal=password="$GIT_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "$ARGOCD_NAMESPACE" label secret repo-sample-web \
    argocd.argoproj.io/secret-type=repository --overwrite
fi

echo "==> Applying Argo CD Application"
kubectl apply -f "$TMP_APP"

save_state
echo "Application 'sample-web' registered."
echo "Watch sync: kubectl get applications -n $ARGOCD_NAMESPACE -w"
echo "App pods:   kubectl get pods,svc -n sample-web"

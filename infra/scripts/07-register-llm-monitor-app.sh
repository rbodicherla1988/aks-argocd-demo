#!/usr/bin/env bash
# Register Argo CD Application for gitops/llm-monitor
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"

if [[ -z "${GIT_REPO_URL}" ]]; then
  echo "GIT_REPO_URL is required." >&2
  echo "  GIT_REPO_URL=https://github.com/<you>/<repo>.git ./07-register-llm-monitor-app.sh" >&2
  exit 1
fi

# Secret must exist before CronJob pods start
if ! kubectl -n llm-monitor get secret llm-monitor-secrets >/dev/null 2>&1; then
  echo "WARNING: Secret llm-monitor-secrets not found in llm-monitor." >&2
  echo "Create it first: ANTHROPIC_API_KEY=... ./05-create-llm-secret.sh" >&2
fi

APP_TEMPLATE="$DEMO_ROOT/gitops/argocd/application-llm-monitor.yaml"
TMP_APP="$(mktemp)"
trap 'rm -f "$TMP_APP"' EXIT

sed \
  -e "s|GIT_REPO_URL|${GIT_REPO_URL}|g" \
  -e "s|targetRevision: HEAD|targetRevision: ${GIT_TARGET_REVISION}|g" \
  "$APP_TEMPLATE" > "$TMP_APP"

kubectl apply -f "$TMP_APP"
save_state
echo "Application 'llm-monitor' registered."
echo "Logs after a run: kubectl logs -n llm-monitor job/<job-name>"
echo "Manual test job:  kubectl create job -n llm-monitor llm-monitor-manual --from=cronjob/llm-monitor"

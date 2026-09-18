#!/usr/bin/env bash
# Create Anthropic API key Secret out-of-band (never commit the key to Git).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"

NS="${LLM_MONITOR_NAMESPACE:-llm-monitor}"
SECRET_NAME="${LLM_MONITOR_SECRET_NAME:-llm-monitor-secrets}"

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "Set ANTHROPIC_API_KEY in the environment (do not paste it into Git)." >&2
  echo "Example:" >&2
  echo "  export ANTHROPIC_API_KEY='...'" >&2
  echo "  ./05-create-llm-secret.sh" >&2
  exit 1
fi

# Basic sanity — do not print the key
if [[ ${#ANTHROPIC_API_KEY} -lt 20 ]]; then
  echo "ANTHROPIC_API_KEY looks too short; aborting." >&2
  exit 1
fi

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" create secret generic "$SECRET_NAME" \
  --from-literal=ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret '$SECRET_NAME' applied in namespace '$NS' (value not logged)."

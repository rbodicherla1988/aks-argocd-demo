#!/usr/bin/env bash
# Build/push llm-monitor image (linux/amd64) and patch CronJob image field.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"

if [[ -z "${ACR_NAME:-}" ]]; then
  echo "ACR_NAME is empty. Run 01-create-rg-acr-aks.sh first (or set ACR_NAME)." >&2
  exit 1
fi

IMAGE_NAME="${LLM_MONITOR_IMAGE_NAME:-llm-monitor}"
IMAGE_TAG="${LLM_MONITOR_IMAGE_TAG:-v1}"
IMAGE_REF="${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

echo "==> Building $IMAGE_REF (linux/amd64)"
az acr login --name "$ACR_NAME"
docker build --platform linux/amd64 \
  -t "$IMAGE_REF" \
  -f "$DEMO_ROOT/agent/Dockerfile" \
  "$DEMO_ROOT/agent"
docker push "$IMAGE_REF"

CRON_YAML="$DEMO_ROOT/gitops/llm-monitor/cronjob.yaml"
echo "==> Patching image in $CRON_YAML"
python3 - "$CRON_YAML" "$IMAGE_REF" <<'PY'
import re, sys
from pathlib import Path
path = Path(sys.argv[1])
image_ref = sys.argv[2]
text = path.read_text()
text2, n = re.subn(r"(?m)^\s*image:\s*\S+", f"              image: {image_ref}", text, count=1)
if n == 0:
    raise SystemExit(f"Could not find image: line in {path}")
path.write_text(text2)
print(f"Updated {path} -> {image_ref}")
PY

save_state
echo "Image ready: $IMAGE_REF"
echo "Commit and push gitops/llm-monitor/cronjob.yaml so Argo CD can sync."

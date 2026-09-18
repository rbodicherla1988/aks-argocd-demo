#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Missing $STATE_FILE — run 01-create-rg-acr-aks.sh first." >&2
  exit 1
fi

IMAGE_REF="${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
echo "==> Building and pushing $IMAGE_REF via az acr build"
az acr build \
  --registry "$ACR_NAME" \
  --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  --file "$DEMO_ROOT/app/Dockerfile" \
  "$DEMO_ROOT/app"

DEPLOY_YAML="$DEMO_ROOT/gitops/sample-web/deployment.yaml"
echo "==> Patching image in $DEPLOY_YAML -> $IMAGE_REF"
python3 - "$DEPLOY_YAML" "$IMAGE_REF" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
image_ref = sys.argv[2]
text = path.read_text()
text2, n = re.subn(r"(?m)^\s*image:\s*\S+", f"          image: {image_ref}", text, count=1)
if n == 0:
    raise SystemExit(f"Could not find image: line in {path}")
path.write_text(text2)
print(f"Updated {path}")
PY

save_state
echo "Image ready: $IMAGE_REF"
echo "Commit and push gitops/sample-web/deployment.yaml so Argo CD can sync the new image."

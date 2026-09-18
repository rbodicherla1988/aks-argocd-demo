#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"

echo "This will DELETE resource group '$RG' and ALL resources inside it."
read -r -p "Type the RG name to confirm: " confirm
if [[ "$confirm" != "$RG" ]]; then
  echo "Aborted."
  exit 1
fi

az group delete --name "$RG" --yes --no-wait
echo "Delete started for $RG (async)."
rm -f "$STATE_FILE"
echo "Local state cleared: $STATE_FILE"

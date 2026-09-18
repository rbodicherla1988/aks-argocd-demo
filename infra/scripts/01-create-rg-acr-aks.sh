#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"

# Prefer persisted ACR_NAME; otherwise generate a unique Basic ACR name
if [[ ! -f "$STATE_FILE" ]] || [[ -z "${ACR_NAME:-}" ]]; then
  suffix="$(openssl rand -hex 3 2>/dev/null || echo ${RANDOM}${RANDOM})"
  ACR_NAME="aksdemo${suffix}"
  ACR_NAME="$(echo "$ACR_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9' | cut -c1-50)"
fi

echo "==> Resource group: $RG ($LOCATION)"
az group create --name "$RG" --location "$LOCATION" -o table

echo "==> ACR: $ACR_NAME (Basic)"
if az acr show --name "$ACR_NAME" --resource-group "$RG" >/dev/null 2>&1; then
  echo "ACR already exists."
else
  az acr create \
    --resource-group "$RG" \
    --name "$ACR_NAME" \
    --sku Basic \
    --admin-enabled false \
    -o table
fi

create_aks() {
  local vm_size="$1"
  az aks create \
    --resource-group "$RG" \
    --name "$AKS_NAME" \
    --node-count "$NODE_COUNT" \
    --node-vm-size "$vm_size" \
    --generate-ssh-keys \
    --enable-managed-identity \
    --attach-acr "$ACR_NAME" \
    --yes \
    -o table
}

echo "==> AKS: $AKS_NAME (nodes=$NODE_COUNT)"
if az aks show --resource-group "$RG" --name "$AKS_NAME" >/dev/null 2>&1; then
  echo "AKS already exists; skipping create."
else
  set +e
  create_aks "$NODE_VM_SIZE"
  create_rc=$?
  set -e
  if [[ $create_rc -ne 0 ]]; then
    echo "AKS create with $NODE_VM_SIZE failed; retrying with $NODE_VM_SIZE_FALLBACK"
    create_aks "$NODE_VM_SIZE_FALLBACK"
  fi
fi

echo "==> Attaching ACR to AKS (idempotent)"
az aks update \
  --resource-group "$RG" \
  --name "$AKS_NAME" \
  --attach-acr "$ACR_NAME" \
  -o none

echo "==> Fetching kubeconfig"
az aks get-credentials \
  --resource-group "$RG" \
  --name "$AKS_NAME" \
  --overwrite-existing

save_state
echo "Saved state to $STATE_FILE"
echo "Cluster ready. Context: $(kubectl config current-context)"
kubectl get nodes -o wide

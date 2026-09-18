#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
  echo "OK: $1 ($(command -v "$1"))"
}

echo "==> Checking required tools"
need az
need kubectl
need helm
need git

echo "==> Checking Azure login"
if ! az account show >/dev/null 2>&1; then
  echo "Not logged in. Run: az login" >&2
  exit 1
fi
az account show --query "{name:name, id:id, tenantId:tenantId}" -o table

echo "==> Checking kubectl cluster (optional until AKS exists)"
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl config current-context
else
  echo "No cluster context yet (expected before 01-create-rg-acr-aks.sh)."
fi

echo "Prereqs OK."

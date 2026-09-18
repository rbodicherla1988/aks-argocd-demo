# AKS + Sample App + ArgoCD (CLI + Monorepo)

Learning demo: provision AKS with Azure CLI, build a sample Node.js web app into ACR, install Argo CD, and GitOps-deploy the app from this folder.

## Prerequisites

- Azure subscription and `az login`
- Local tools: `az`, `kubectl`, `helm`, `git`, `python3`
- A **git remote** that Argo CD can clone (public GitHub is simplest). The repo **root** must be this `aks-argocd-demo` directory (so `gitops/sample-web` exists at the repo root).

## Layout

```
aks-argocd-demo/
  app/                      # Express sample web app + Dockerfile
  agent/                    # Phase-0 Claude read-only monitor
  gitops/sample-web/        # K8s manifests Argo CD syncs
  gitops/llm-monitor/       # CronJob + RBAC + NetworkPolicy (no live secrets)
  gitops/argocd/            # Argo CD Application CR templates
  infra/scripts/            # Azure CLI / Helm runbook
```

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `RG` | `aks-argocd-demo-rg` | Resource group |
| `LOCATION` | `eastus` | Azure region |
| `AKS_NAME` | `aks-argocd-demo` | Cluster name |
| `ACR_NAME` | auto-generated | Container registry (globally unique) |
| `NODE_COUNT` | `2` | System node pool size |
| `NODE_VM_SIZE` | `Standard_B2s` | Falls back to `Standard_D2s_v3` |
| `IMAGE_TAG` | `v1` | Image tag built into ACR |
| `GIT_REPO_URL` | *(required for step 04)* | Git remote for Argo CD |
| `GITOPS_PATH` | `gitops/sample-web` | Path inside the git repo |
| `GIT_USERNAME` / `GIT_PASSWORD` | optional | Private HTTPS repo credentials |

Successful runs persist names under `infra/scripts/.state/env.local` (gitignored).

## Run order

From this directory:

```bash
cd aks-argocd-demo/infra/scripts

./00-prereqs.sh

# Optional overrides:
# export LOCATION=centralindia RG=my-demo-rg

./01-create-rg-acr-aks.sh    # ~10–15 min
./02-install-argocd.sh       # prints UI URL + admin password
./03-build-push-image.sh     # az acr build + patches deployment.yaml image
```

### Push manifests to git (required before Argo CD sync)

Argo CD pulls from git — not from your local disk.

```bash
# One-time: make aks-argocd-demo its own git repo (or add this folder to an existing remote)
cd ../..   # aks-argocd-demo
git init
git add .
git commit -m "Initial AKS ArgoCD demo"
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin HEAD
```

Then register the Application:

```bash
cd infra/scripts
export GIT_REPO_URL=https://github.com/<you>/<repo>.git
# Private repo:
# export GIT_USERNAME=<user> GIT_PASSWORD=<pat>

./04-register-argocd-app.sh
```

## Verify

```bash
# Argo CD Application
kubectl get applications -n argocd

# Workload
kubectl get pods,svc -n sample-web

# Hit the app LoadBalancer
EXTERNAL_IP=$(kubectl get svc sample-web -n sample-web -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s "http://$EXTERNAL_IP/"
curl -s "http://$EXTERNAL_IP/healthz"
```

Open the Argo CD UI (URL + password from step 02). Application `sample-web` should be Synced / Healthy.

### GitOps feedback loop

1. Edit `gitops/sample-web/deployment.yaml` (e.g. `replicas: 3` or `APP_MESSAGE`)
2. Commit and push
3. Argo CD auto-syncs (prune + selfHeal enabled)

## Teardown (stop Azure spend)

```bash
cd infra/scripts
./99-teardown.sh
```

## Claude llm-monitor (Phase 0)

Read-only CronJob that collects `sample-web` facts, calls Claude, and logs a JSON health report.

**Guardrails:** dedicated ServiceAccount, namespace Role (get/list/watch only), NetworkPolicy, allowlisted health URL, output schema validation, Cron every 6h, kill switch via ConfigMap `AGENT_ENABLED` or CronJob `suspend`.

**Secrets stay out of Git.** Create the API key Secret on the cluster:

```bash
export ANTHROPIC_API_KEY='...'   # from Anthropic console — never commit
./infra/scripts/05-create-llm-secret.sh
```

After AKS/ACR/Argo exist:

```bash
cd infra/scripts
./06-build-push-llm-monitor.sh
# commit + push patched gitops/llm-monitor/cronjob.yaml image line
GIT_REPO_URL=https://github.com/rbodicherla1988/aks-argocd-demo.git ./07-register-llm-monitor-app.sh
```

Manual run:

```bash
kubectl create job -n llm-monitor llm-monitor-manual --from=cronjob/llm-monitor
kubectl logs -n llm-monitor -l job-name=llm-monitor-manual -f
```

Suspend without deleting:

```bash
# In gitops/llm-monitor/cronjob.yaml set suspend: true  OR
# ConfigMap AGENT_ENABLED: "false"
```

## Notes

- ACR is attached to AKS (`--attach-acr`) so no `imagePullSecrets` are needed.
- Argo CD server is exposed as a LoadBalancer for learning simplicity. Harden later with Ingress + TLS.
- Out of scope for this demo: Terraform/Bicep, Ingress, cert-manager, CI pipelines, multi-env App-of-Apps.

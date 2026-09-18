# llm-monitor agent (Phase 0)

Read-only Claude narrator for the `sample-web` namespace.

## Behavior
1. Kill switch: `AGENT_ENABLED` (ConfigMap)
2. Collect pods/deployments/events + health probe (allowlisted URL)
3. Redact obvious secret patterns
4. Call Anthropic Messages API
5. Validate JSON schema; print report to stdout

## Non-goals (Phase 0)
- No cluster mutations
- No shell/`kubectl apply`
- No API keys in Git (use `infra/scripts/05-create-llm-secret.sh`)

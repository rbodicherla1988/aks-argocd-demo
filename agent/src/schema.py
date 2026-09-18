"""Strict JSON report schema validation."""

from __future__ import annotations

from typing import Any


ALLOWED_STATUS = {"ok", "degraded", "down", "unknown"}
ALLOWED_SEVERITY = {"low", "medium", "high"}


def validate_report(data: Any) -> dict:
    if not isinstance(data, dict):
        raise ValueError("report must be a JSON object")

    status = data.get("status")
    if status not in ALLOWED_STATUS:
        raise ValueError(f"invalid status: {status!r}")

    summary = data.get("summary")
    if not isinstance(summary, str) or not summary.strip():
        raise ValueError("summary must be a non-empty string")
    if len(summary) > 2000:
        raise ValueError("summary too long")

    findings = data.get("findings", [])
    if not isinstance(findings, list):
        raise ValueError("findings must be a list")
    clean_findings = []
    for item in findings[:20]:
        if not isinstance(item, dict):
            raise ValueError("finding must be an object")
        sev = item.get("severity")
        title = item.get("title")
        evidence = item.get("evidence")
        if sev not in ALLOWED_SEVERITY:
            raise ValueError(f"invalid severity: {sev!r}")
        if not isinstance(title, str) or not title.strip():
            raise ValueError("finding.title required")
        if not isinstance(evidence, str):
            raise ValueError("finding.evidence must be a string")
        clean_findings.append(
            {"severity": sev, "title": title[:200], "evidence": evidence[:1000]}
        )

    actions = data.get("recommended_actions", [])
    if not isinstance(actions, list):
        raise ValueError("recommended_actions must be a list")
    clean_actions = []
    for a in actions[:10]:
        if not isinstance(a, str) or not a.strip():
            raise ValueError("recommended_actions entries must be strings")
        clean_actions.append(a[:500])

    return {
        "status": status,
        "summary": summary.strip()[:2000],
        "findings": clean_findings,
        "recommended_actions": clean_actions,
    }

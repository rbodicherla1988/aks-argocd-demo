#!/usr/bin/env python3
"""Phase-0 Claude AKS monitor: collect facts -> Claude -> validated JSON -> stdout."""

from __future__ import annotations

import json
import re
import sys

from claude_client import call_claude
from collect import collect_facts
from guardrails import SYSTEM_PROMPT, agent_enabled, max_tokens
from schema import validate_report


def _extract_json(text: str) -> object:
    text = text.strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    # Tolerate accidental markdown fences from the model
    fence = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
    if fence:
        return json.loads(fence.group(1).strip())
    start, end = text.find("{"), text.rfind("}")
    if start >= 0 and end > start:
        return json.loads(text[start : end + 1])
    raise ValueError("no JSON object found in model response")


def main() -> int:
    if not agent_enabled():
        print(json.dumps({"skipped": True, "reason": "AGENT_ENABLED=false"}))
        return 0

    facts = collect_facts()
    user_prompt = (
        "Analyze these FACTS and return ONLY a JSON object with keys: "
        "status, summary, findings, recommended_actions.\n\n"
        "status must be one of: ok, degraded, down, unknown.\n"
        "findings is an array of {severity, title, evidence}.\n"
        "recommended_actions is an array of short advisory strings.\n\n"
        f"FACTS:\n{json.dumps(facts, indent=2)}"
    )

    raw = call_claude(SYSTEM_PROMPT, user_prompt, max_tokens=max_tokens())
    report = validate_report(_extract_json(raw))
    report["facts_namespace"] = facts.get("namespace")
    report["collected_at"] = facts.get("collected_at")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        print(json.dumps({"status": "unknown", "error": str(exc)[:800]}), file=sys.stderr)
        raise SystemExit(1) from exc

"""Minimal Anthropic Messages API client (HTTPS only)."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from typing import Any


def call_claude(system: str, user_content: str, max_tokens: int) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("ANTHROPIC_API_KEY is not set")

    model = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-5").strip()
    api_url = os.environ.get(
        "ANTHROPIC_API_URL", "https://api.anthropic.com/v1/messages"
    ).strip()

    payload: dict[str, Any] = {
        "model": model,
        "max_tokens": max_tokens,
        "system": system,
        "messages": [{"role": "user", "content": user_content}],
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        api_url,
        data=data,
        method="POST",
        headers={
            "content-type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")[:800]
        raise RuntimeError(f"Anthropic API HTTP {e.code}: {err}") from e

    parts = []
    for block in body.get("content") or []:
        if isinstance(block, dict) and block.get("type") == "text":
            parts.append(block.get("text") or "")
    text = "\n".join(parts).strip()
    if not text:
        raise RuntimeError("Anthropic API returned empty content")
    return text

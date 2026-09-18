"""Read-only fact collection. No create/update/delete calls."""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any

from kubernetes import client, config
from kubernetes.client.rest import ApiException

from guardrails import health_url, monitor_namespace, redact_obj


def _load_api() -> tuple[client.CoreV1Api, client.AppsV1Api]:
    try:
        config.load_incluster_config()
    except config.ConfigException:
        config.load_kube_config()
    return client.CoreV1Api(), client.AppsV1Api()


def _http_get(url: str, timeout: float = 5.0) -> dict[str, Any]:
    req = urllib.request.Request(url, method="GET", headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8", errors="replace")[:2000]
            return {"ok": True, "status_code": resp.status, "body": body}
    except urllib.error.HTTPError as e:
        return {"ok": False, "status_code": e.code, "body": str(e)[:500]}
    except Exception as e:  # noqa: BLE001 - surface probe errors as facts
        return {"ok": False, "status_code": None, "body": str(e)[:500]}


def collect_facts() -> dict[str, Any]:
    ns = monitor_namespace()
    core, apps = _load_api()

    pods_out: list[dict[str, Any]] = []
    try:
        pods = core.list_namespaced_pod(ns)
        for p in pods.items:
            containers = []
            for cs in (p.status.container_statuses or []):
                waiting = None
                if cs.state and cs.state.waiting:
                    waiting = cs.state.waiting.reason
                containers.append(
                    {
                        "name": cs.name,
                        "ready": bool(cs.ready),
                        "restart_count": cs.restart_count,
                        "waiting_reason": waiting,
                    }
                )
            pods_out.append(
                {
                    "name": p.metadata.name,
                    "phase": p.status.phase,
                    "containers": containers,
                }
            )
    except ApiException as e:
        pods_out = [{"error": f"list pods failed: {e.status}"}]

    deploy_out: list[dict[str, Any]] = []
    try:
        deps = apps.list_namespaced_deployment(ns)
        for d in deps.items:
            deploy_out.append(
                {
                    "name": d.metadata.name,
                    "replicas": d.status.replicas,
                    "ready_replicas": d.status.ready_replicas,
                    "unavailable_replicas": d.status.unavailable_replicas,
                }
            )
    except ApiException as e:
        deploy_out = [{"error": f"list deployments failed: {e.status}"}]

    events_out: list[dict[str, Any]] = []
    try:
        events = core.list_namespaced_event(ns)
        # Prefer Warning events; cap volume for prompt-injection / token budget
        warnings = [ev for ev in events.items if (ev.type or "") == "Warning"]
        warnings.sort(key=lambda ev: ev.last_timestamp or ev.event_time or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
        for ev in warnings[:15]:
            events_out.append(
                {
                    "reason": ev.reason,
                    "message": (ev.message or "")[:300],
                    "involved": getattr(ev.involved_object, "name", None),
                    "count": ev.count,
                }
            )
    except ApiException as e:
        events_out = [{"error": f"list events failed: {e.status}"}]

    health = _http_get(health_url())

    facts = {
        "collected_at": datetime.now(timezone.utc).isoformat(),
        "namespace": ns,
        "health_probe": health,
        "deployments": deploy_out,
        "pods": pods_out,
        "warning_events": events_out,
    }
    return redact_obj(facts)

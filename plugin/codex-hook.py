#!/usr/bin/env python3
"""Write ~/.codex/pets/deskpet-state.json from a Codex lifecycle hook."""
from __future__ import annotations

import json
import os
import sys
import tempfile
import time
from pathlib import Path

DEST_DIR = Path.home() / ".codex" / "pets"
DEST = DEST_DIR / "deskpet-state.json"
EVENTS = DEST_DIR / "deskpet-events.jsonl"

RUNNING_EVENTS = {
    "userpromptsubmit",
    "pretooluse",
    "posttooluse",
    "subagentstart",
    "subagentstop",
}
WAITING_EVENTS = {"permissionrequest"}
FAILED_EVENTS = {"posttoolusefailure"}
REVIEW_EVENTS = {"stop", "sessionend", "interrupt"}


def load_payload() -> dict:
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    try:
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def event_name(data: dict) -> str:
    for key in ("hook_event_name", "event", "type", "hookEventName"):
        value = data.get(key)
        if value:
            return str(value)
    return os.environ.get("CODEX_HOOK_EVENT") or ""


def tool_name(data: dict) -> str:
    for key in ("tool_name", "toolName", "tool"):
        value = data.get(key)
        if value:
            return str(value)
    tool_input = data.get("tool_input")
    if isinstance(tool_input, dict):
        for key in ("tool", "name"):
            value = tool_input.get(key)
            if value:
                return str(value)
    return ""


def detail_text(data: dict, tool: str) -> str:
    tool_input = data.get("tool_input")
    if isinstance(tool_input, dict):
        desc = tool_input.get("description")
        if isinstance(desc, str) and desc.strip():
            return desc.strip()[:80]
    return tool


def kind_for(event: str) -> str:
    key = event.replace("_", "").lower()
    if key in WAITING_EVENTS or "permission" in key:
        return "waiting"
    if key in FAILED_EVENTS or "fail" in key or "error" in key:
        return "failed"
    if key in REVIEW_EVENTS:
        return "review"
    if key in RUNNING_EVENTS:
        return "running"
    return "running"


def write_state(state: str, extra: dict) -> None:
    DEST_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "state": state,
        "source": "codex",
        "updatedAt": time.time(),
        **extra,
    }
    fd, tmp = tempfile.mkstemp(prefix="deskpet-state-", suffix=".json", dir=str(DEST_DIR))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False)
        os.replace(tmp, DEST)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
    if state in {"waiting", "failed", "review"}:
        append_event(payload)


def append_event(payload: dict) -> None:
    try:
        if EVENTS.exists() and EVENTS.stat().st_size > 400_000:
            lines = EVENTS.read_text(encoding="utf-8").splitlines()[-150:]
            EVENTS.write_text("\n".join(lines) + "\n", encoding="utf-8")
        with EVENTS.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(payload, ensure_ascii=False) + "\n")
    except Exception:
        pass


def main() -> None:
    data = load_payload()
    event = event_name(data)
    if not event:
        return
    tool = tool_name(data)
    kind = kind_for(event)
    extra = {"type": event}
    detail = detail_text(data, tool)
    if tool:
        extra["tool"] = tool
    if detail:
        extra["detail"] = detail
    cwd = data.get("cwd")
    if isinstance(cwd, str) and cwd.strip():
        extra["cwd"] = cwd.strip()
    session = data.get("session_id") or data.get("sessionId")
    if isinstance(session, str) and session.strip():
        extra["sessionId"] = session.strip()
    pane = os.environ.get("ORCA_PANE_KEY") or data.get("paneKey")
    if isinstance(pane, str) and pane.strip():
        extra["paneKey"] = pane.strip()
    tab = os.environ.get("ORCA_TAB_ID") or data.get("tabId")
    if isinstance(tab, str) and tab.strip():
        extra["tabId"] = tab.strip()
    worktree = os.environ.get("ORCA_WORKTREE_ID") or data.get("worktreeId")
    if isinstance(worktree, str) and worktree.strip():
        extra["worktreeId"] = worktree.strip()
    write_state(kind, extra)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass

#!/usr/bin/env python3
"""Copy the Codex hook and merge it into Codex and Orca hooks.json files."""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

EVENTS = [
    "UserPromptSubmit",
    "PreToolUse",
    "PostToolUse",
    "PermissionRequest",
    "Stop",
    "SubagentStart",
    "SubagentStop",
]

MARKER = "codex-hook.py"


def command_for(script: Path) -> str:
    return f'/usr/bin/python3 "{script}"'


def hook_files() -> list[Path]:
    home = Path.home()
    return [
        home / ".codex" / "hooks.json",
        home
        / "Library"
        / "Application Support"
        / "orca"
        / "codex-runtime-home"
        / "home"
        / "hooks.json",
    ]


def is_deskpet_block(block: object) -> bool:
    if not isinstance(block, dict):
        return False
    hooks = block.get("hooks")
    if not isinstance(hooks, list):
        return False
    for hook in hooks:
        if not isinstance(hook, dict):
            continue
        command = str(hook.get("command") or "")
        if MARKER in command or "deskpet" in command and "codex-hook" in command:
            return True
    return False


def load_hooks(path: Path) -> dict:
    if not path.exists():
        return {"hooks": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            hooks = data.get("hooks")
            if not isinstance(hooks, dict):
                data["hooks"] = {}
            return data
    except Exception:
        pass
    return {"hooks": {}}


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    tmp.replace(path)


def install(src: Path, dest: Path, hooks_path: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    dest.chmod(0o755)
    merge_hooks(dest, hooks_path)
    print(f"deskpet: installed Codex hook -> {dest}")
    for path in extra_paths(hooks_path):
        if path.exists():
            merge_hooks(dest, path)
            print(f"deskpet: merged {path}")
    print("deskpet: trust the new hook with /hooks in Codex and Orca terminals")


def extra_paths(primary: Path) -> list[Path]:
    seen = {primary.resolve()}
    out: list[Path] = []
    for path in hook_files():
        resolved = path.resolve() if path.exists() else path
        if resolved in seen:
            continue
        seen.add(resolved)
        out.append(path)
    return out


def merge_hooks(script: Path, hooks_path: Path) -> None:
    data = load_hooks(hooks_path)
    hooks = data["hooks"]
    entry = {
        "hooks": [
            {
                "type": "command",
                "command": command_for(script),
                "timeout": 2,
            }
        ]
    }
    for event in EVENTS:
        blocks = hooks.get(event)
        if not isinstance(blocks, list):
            blocks = []
        blocks = [block for block in blocks if not is_deskpet_block(block)]
        blocks.append(entry)
        hooks[event] = blocks
    write_json(hooks_path, data)


def uninstall(dest: Path, hooks_path: Path) -> None:
    data = load_hooks(hooks_path)
    hooks = data.get("hooks")
    changed = False
    if isinstance(hooks, dict):
        for event, blocks in list(hooks.items()):
            if not isinstance(blocks, list):
                continue
            kept = [block for block in blocks if not is_deskpet_block(block)]
            if len(kept) != len(blocks):
                changed = True
            if kept:
                hooks[event] = kept
            else:
                hooks.pop(event, None)
    if changed:
        write_json(hooks_path, data)
        print(f"deskpet: removed Codex hook entries from {hooks_path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("src", nargs="?", help="plugin/codex-hook.py")
    parser.add_argument("--uninstall", action="store_true")
    parser.add_argument(
        "--dest",
        default=str(Path.home() / ".codex" / "pets" / "codex-hook.py"),
    )
    parser.add_argument(
        "--hooks",
        default=str(Path.home() / ".codex" / "hooks.json"),
    )
    args = parser.parse_args()
    dest = Path(args.dest).expanduser()
    hooks_path = Path(args.hooks).expanduser()
    if args.uninstall:
        uninstall(dest, hooks_path)
        for path in extra_paths(hooks_path):
            if path.exists():
                uninstall(dest, path)
        if dest.exists():
            dest.unlink()
            print(f"deskpet: removed {dest}")
        return 0
    if not args.src:
        print("deskpet: missing hook source", file=sys.stderr)
        return 2
    src = Path(args.src).expanduser().resolve()
    if not src.exists():
        print(f"deskpet: missing {src}", file=sys.stderr)
        return 2
    install(src, dest, hooks_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

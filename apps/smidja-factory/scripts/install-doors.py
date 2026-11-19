#!/usr/bin/env python3
"""install-doors.py — put the smithy's two doors where every harness finds them.

  1. the command: `smidja` and `smidja-mcp` linked onto PATH (~/.local/bin), and the smithy's books
     on the harness-wide skill shelf (~/.pi/agent/skills/smidja-factory)
  2. the MCP: one `smidja` server named in pi's MCP set (~/.pi/agent/mcp-adapter.json
     and mcp.json), the ONE source the house copies to every harness — then, when
     Ymir is on this machine, its seating door (bin/bridge/mcp-config.sh seat, and
     bin/seat/hermes-seat.sh) carries that set into Claude Code, Codex, OpenCode,
     Cursor and Hermes. Without Ymir, the per-harness lines to run are printed.

Only pi works INSIDE a smithy run; every harness may DRIVE one through these doors.

A named merge: only the `smidja` entry is touched; every other server stays. A file
it changes is backed up first (<file>.bak-<UTC stamp>). Idempotent.

Usage:
  install-doors.py            seat both doors
  install-doors.py --check    say what would change; change nothing (exit 1 on drift)
  install-doors.py --no-harnesses   pi's set and PATH only; do not run the house seating door
"""

from __future__ import annotations

import datetime as _dt
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

# The doors name the smithy by the path that survives an update: the apps home's `current` link when
# the app is installed there (activate.sh passes it), else the folder this script ships in.
FACTORY = Path(os.environ.get("SMIDJA_FACTORY_LINK") or Path(__file__).resolve().parents[1])
HOME = Path(os.environ.get("HOME", str(Path.home())))
STAMP = _dt.datetime.now(_dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
CHECK = "--check" in sys.argv
NO_HARNESSES = "--no-harnesses" in sys.argv
rows: list[tuple[str, str, str]] = []
drift = 0


def say(door: str, state: str, detail: str) -> None:
    global drift
    if state in ("would change", "missing"):
        drift += 1
    rows.append((door, state, detail))


def link(name: str) -> None:
    target = FACTORY / "scripts" / name
    dest = HOME / ".local" / "bin" / name
    if dest.is_symlink() and Path(os.readlink(dest)) == target:
        return say(f"PATH {name}", "ok", str(dest))
    if dest.exists() and not dest.is_symlink():
        return say(f"PATH {name}", "refused", f"{dest} is a real file, not ours — left alone")
    if CHECK:
        return say(f"PATH {name}", "would change", f"{dest} -> {target}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.is_symlink():
        dest.unlink()
    dest.symlink_to(target)
    say(f"PATH {name}", "linked", f"{dest} -> {target}")


def link_skills() -> None:
    """The smithy's books on the harness-wide shelf (~/.pi/agent/skills, shelf 4), so `skill-find.sh` and
    the one Ymir skill (which indexes every shelf for every harness) still find them once the app has
    left Ymir's tree, where `.agents/skills/smidja-factory` used to point into apps/."""
    dest = HOME / ".pi" / "agent" / "skills" / "smidja-factory"
    if dest.is_symlink() and Path(os.readlink(dest)) == FACTORY:
        return say("skills", "ok", str(dest))
    if dest.exists() and not dest.is_symlink():
        return say("skills", "refused", f"{dest} is a real folder, not ours — left alone")
    if CHECK:
        return say("skills", "would change", f"{dest} -> {FACTORY}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.is_symlink():
        dest.unlink()
    dest.symlink_to(FACTORY)
    say("skills", "linked", f"{dest} -> {FACTORY}")


def want_entry() -> dict:
    return {"command": str(FACTORY / "scripts" / "smidja-mcp"), "args": [],
            "description": "Smíðja, the smithy: start, watch and steer agent-factory runs (only pi works inside)"}


def seat_pi_source() -> None:
    d = HOME / ".pi" / "agent"
    for path in (d / "mcp-adapter.json", d / "mcp.json"):
        if not path.exists() and path.name == "mcp.json" and not (d / "mcp-adapter.json").exists():
            continue
        try:
            data = json.loads(path.read_text()) if path.exists() else {}
        except ValueError:
            say(f"pi {path.name}", "refused", "not valid JSON — left alone")
            continue
        servers = data.setdefault("mcpServers", {}) if "mcpServers" in data or not data else data
        if servers.get("smidja") == want_entry():
            say(f"pi {path.name}", "ok", "smidja seated")
            continue
        if CHECK:
            say(f"pi {path.name}", "would change", "add the smidja server")
            continue
        if path.exists():
            shutil.copy2(path, path.with_name(f"{path.name}.bak-{STAMP}"))
        servers["smidja"] = want_entry()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=2) + "\n")
        say(f"pi {path.name}", "seated", str(path))


def ymir_root() -> Path | None:
    for value in (os.environ.get("YMIR_ROOT"), os.environ.get("YMIR_RUNTIME_DIR")):
        if value and (Path(value) / "bin" / "bridge" / "mcp-config.sh").is_file():
            return Path(value)
    for cand in (FACTORY.parent.parent, HOME / "ymir-runtime"):
        if (cand / "bin" / "bridge" / "mcp-config.sh").is_file():
            return cand
    return None


def seat_harnesses() -> None:
    root = ymir_root()
    if root is None:
        entry = want_entry()["command"]
        say("harnesses", "manual", "no Ymir here — seat by hand: "
            f"claude mcp add --scope user smidja {entry} · codex mcp add smidja -- {entry} · "
            f"opencode: mcp.smidja = {{type: local, command: [{entry}]}} · hermes: mcp_servers.smidja.command = {entry}")
        return
    flag = ["--check"] if CHECK else []
    for label, cmd in (("claude · codex · opencode · cursor", ["bash", str(root / "bin/bridge/mcp-config.sh"), "seat", *flag]),
                       ("hermes", ["bash", str(root / "bin/seat/hermes-seat.sh"), *flag])):
        if not Path(cmd[1]).is_file():
            say(label, "skip", f"{cmd[1]} not on this machine")
            continue
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        detail = (out.stdout.strip().splitlines() or [""])[-1][:160]
        say(label, "ok" if out.returncode == 0 else ("would change" if CHECK else "failed"),
            f"through {Path(cmd[1]).name}: {detail}")


def main() -> int:
    for name in ("smidja", "smidja-mcp"):
        link(name)
    link_skills()
    seat_pi_source()
    if not NO_HARNESSES:
        seat_harnesses()
    print(f"smidja-doors[{len(rows)}]{{door,state,detail}}:")
    for r in rows:
        print("  " + ",".join(json.dumps(x, ensure_ascii=False) for x in r))
    if any(state in ("refused", "failed") for _, state, _ in rows):
        return 1
    return 1 if (CHECK and drift) else 0


if __name__ == "__main__":
    sys.exit(main())

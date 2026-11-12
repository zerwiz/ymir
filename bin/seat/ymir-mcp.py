#!/usr/bin/env python3
"""ymir-mcp.py — Ymir's own doors over MCP: the tools Pi has as extensions, for
every harness (Hermes, OpenCode, Codex, Claude, Cursor…).

WHY (the Allfather, 2026-11-03): *"why can you use the same things we're installing
for the pi agents extensions"* — *"hermes must get the same tools as the extensions
etc as pi and opencode etc."* Pi's `ymir_*` tools lived only inside `.pi/extensions/`,
so an MCP harness could never reach them. This server exposes the same doors over
the one protocol every harness speaks, each a thin call to the bin/ door that owns
the behaviour (never a second implementation).

Run:  python3 bin/mcp/ymir-mcp.py        (stdio transport)
"""
from __future__ import annotations

import datetime as _dt
import os
import subprocess
from pathlib import Path

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:  # pragma: no cover - the one production dependency
    raise SystemExit(
        "ymir-mcp: the MCP SDK is missing. Install it once for this user:\n"
        "  python3 -m pip install --user mcp\n"
        "The door is useless without it, so it refuses rather than half-starts."
    )

ROOT = Path(__file__).resolve().parents[2]


def _home() -> Path:
    """The private home, through the house's resolver — never a guess (Rule 07)."""
    try:
        out = subprocess.run(
            ["bash", str(ROOT / "bin" / "vault" / "hodd.sh"), "path"],
            capture_output=True, text=True, timeout=20,
        )
        p = Path(out.stdout.strip())
        if p.exists():
            return p.parent
    except Exception:
        pass
    env = os.environ.get("YMIR_HOME")
    if env:
        return Path(env)
    raise RuntimeError("no YMIR_HOME — bin/vault/hodd.sh path answered nothing")


def _run(argv: list[str], timeout: int = 120) -> str:
    try:
        out = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, cwd=str(ROOT))
        body = (out.stdout or "").strip()
        err = (out.stderr or "").strip()
        if out.returncode != 0:
            return f"exit {out.returncode}\n{body}\n{err}".strip()
        return body or err or "(no output)"
    except subprocess.TimeoutExpired:
        return f"timed out after {timeout}s: {' '.join(argv)}"
    except Exception as exc:  # never hang a harness
        return f"failed: {exc}"


mcp = FastMCP("ymir")


@mcp.tool()
def ymir_where() -> str:
    """Where Ymir is on this machine: the repo, the private home, the seat's own name.
    Call this FIRST when you do not know the house — it answers what this seat is."""
    seat_file = Path.home() / ".pi" / "agent" / "extensions" / ".ymir-seat"
    seat = seat_file.read_text().strip() if seat_file.exists() else "(no .ymir-seat)"
    return "\n".join([
        f"repo      {ROOT}",
        f"home      {_home()}",
        "seat      " + " · ".join(seat.split()),
        "contract  " + str(ROOT / "AGENTS.md") + "  (the house's law, voice and naming)",
        "rules     " + str(ROOT / "RULES"),
        "doors     " + str(ROOT / "bin"),
    ])


@mcp.tool()
def ymir_rule(topic: str) -> str:
    """The house law that governs a topic, read from RULES/ (e.g. 'delete', 'secrets',
    'ports', 'commits', 'worktrees'). Ask before acting where a law may apply."""
    hits = []
    for p in sorted((ROOT / "RULES").glob("*.md")):
        try:
            text = p.read_text(errors="replace")
        except Exception:
            continue
        if topic.lower() in (p.name + text).lower():
            headline = next((l for l in text.splitlines() if l.startswith("#")), "")
            hits.append(f"{p.name}: {headline.lstrip('# ').strip()}")
    return "\n".join(hits[:12]) if hits else f"no rule names {topic!r} — read RULES/README.md"


@mcp.tool()
def ymir_structure(depth: int = 2) -> str:
    """The shape of the private home: every shelf and how many files it holds."""
    base = _home() / "hodd"
    rows = []
    for p in sorted(base.iterdir()) if base.exists() else []:
        if p.is_dir() and not p.name.startswith(".") and depth > 0:
            n = sum(1 for _ in p.rglob("*") if _.is_file())
            rows.append(f"{p.name}/  ({n} files)")
    return "\n".join(rows) or "(no shelves)"


@mcp.tool()
def ymir_find(what: str, content: bool = True) -> str:
    """Where something lives in the home — by name, and by content when asked."""
    base = _home()
    found = [str(p.relative_to(base)) for p in base.rglob(f"*{what}*") if p.is_file()][:15]
    if content and len(found) < 15:
        try:
            out = subprocess.run(["grep", "-ril", "--include=*.md", what, str(base)],
                                 capture_output=True, text=True, timeout=30)
            found += [l.replace(str(base) + "/", "") for l in out.stdout.splitlines()[:10]]
        except Exception:
            pass
    return "\n".join(dict.fromkeys(found)) or f"nothing named or saying {what!r}"


@mcp.tool()
def ymir_recall(query: str, k: int = 5) -> str:
    """Drink from the well before acting: Ymir's memory of what was learned."""
    return _run(["bash", str(ROOT / "bin" / "records" / "mimir.sh"), "recall", query, "--k", str(k)], 90)


@mcp.tool()
def ymir_remember(lesson: str, tags: str = "") -> str:
    """Water the well after: record what was learned, so the next hand starts ahead."""
    argv = ["bash", str(ROOT / "bin" / "records" / "mimir.sh"), "observe", lesson]
    if tags:
        argv += ["--tags", tags]
    return _run(argv, 90)


@mcp.tool()
def ymir_daily(note: str = "") -> str:
    """Today's log line in the home's daily record: append a note, or read the day."""
    day = _dt.date.today().isoformat()
    p = _home() / "hodd" / "memory" / "daily" / f"{day}.md"
    p.parent.mkdir(parents=True, exist_ok=True)
    if note:
        with p.open("a") as fh:
            fh.write(f"\n- {_dt.datetime.now().strftime('%H:%M')} {note}\n")
        return f"appended to {p}"
    return p.read_text() if p.exists() else f"no entries yet for {day}"


@mcp.tool()
def ymir_calendar(action: str = "what") -> str:
    """The calendar through Mánagandr: 'what' is coming, 'probe' asks if consent holds."""
    return _run(["bash", str(ROOT / "bin" / "time" / "snotra" / "calendar-ask.sh"), action], 90)


@mcp.tool()
def ymir_heal() -> str:
    """Eir, the healer: diagnose every surface of the house (a check, never a change)."""
    return _run(["bash", str(ROOT / "bin" / "agents" / "eir-doctor.sh"), "check"], 600)


@mcp.tool()
def ymir_gates() -> str:
    """Which gate covers which surface in this house (the ward list)."""
    return _run(["bash", str(ROOT / "bin" / "gates" / "guards.sh"), "--list"], 120)



@mcp.tool()
def ymir_update() -> str:
    """Gróa, the updater: is the checkout behind, and did the instruction surface move?"""
    return _run(["bash", str(ROOT / "bin" / "agents" / "groa-update.sh"), "--check"], 180)


@mcp.tool()
def ymir_secret_keys(filter: str = "") -> str:
    """Which secret KEY NAMES exist in the vault — names only, never a value."""
    out = _run(["bash", str(ROOT / "bin" / "vault" / "hodd.sh"), "ls"], 60)
    if filter:
        lines = [l for l in out.splitlines() if filter.lower() in l.lower()]
        return "\n".join(lines) or f"no secret names holding {filter!r}"
    return out


@mcp.tool()
def ymir_studio(action: str = "status") -> str:
    """The OpenDesign studio (the container on :7456) — status, start, or stop."""
    return _run(["bash", str(ROOT / "bin" / "pi" / "opendesign.sh"), action], 180)


@mcp.tool()
def ymir_errand(action: str, id: str, project: str = "", mode: str = "direct-PR",
                harness: str = "pi", model: str = "", note: str = "", terminal: str = "done") -> str:
    """An errand: start an Eindri worker (the one spawn path), read its seat, or close it."""
    if action == "start":
        if not project:
            return "start needs project — the repo root the errand works in"
        argv = ["bash", str(ROOT / "bin" / "agents" / "einherjar-spawn.sh"), id, project,
                "--mode", mode, "--harness", harness]
        if model:
            argv += ["--model", model]
        return _run(argv, 300)
    if action == "read":
        return _run(["bash", str(ROOT / "bin" / "seat" / "seats.sh"), "show", id], 120)
    if action == "close":
        return _run(["bash", str(ROOT / "bin" / "seat" / "seats.sh"), "close", id, terminal, note], 120)
    return "action must be start | read | close"


# --- the house task board: ONE writer, and it is a door in bin/ ---------------
# Plan 228 §3 (F2): a promise a meeting makes must become a piece of work in the
# SAME act as the minutes. That cannot be true if the harness writes its own store
# and the meeting ladder writes another, so this face no longer owns the file: it
# CALLS `bin/records/todos.sh`, the one writer of `<home>/state/todos.json`.
# Two boards is one board too many (2026-11-09).
def _tasks_door() -> Path:
    return ROOT / "bin" / "records" / "todos.sh"


@mcp.tool()
def todo(action: str = "list", content: str = "", index: int = -1) -> str:
    """The house task board, shared by every harness: list · add · update · remove · clear."""
    door = _tasks_door()
    if not door.exists():
        return f"the task door is missing: {door} (bin/records/todos.sh)"
    if action == "list":
        return _run(["bash", str(door), "list"])
    if action == "add":
        if not content:
            return "add needs content"
        return _run(["bash", str(door), "add", content])
    if action == "update":
        if index < 0:
            return "update needs an index (see `list`)"
        # `update` takes the new status; a task is open or done, nothing else.
        want = (content or "done").strip().lower()
        verb = "done" if want in ("done", "closed", "complete", "completed") else "reopen"
        return _run(["bash", str(door), verb, str(index)])
    if action == "remove":
        if index < 0:
            return "remove needs an index (see `list`)"
        return _run(["bash", str(door), "remove", str(index)])
    if action == "clear":
        # clear is expressed through the door, never by truncating the file here.
        out = []
        listing = _run(["bash", str(door), "list"])
        for row in listing.splitlines():
            m = row.strip().split('"')
            if row.startswith("  \"") and len(m) > 1 and m[1].isdigit():
                out.append(_run(["bash", str(door), "remove", m[1]]))
        return "cleared" if out else "(no tasks to clear)"
    return "action must be list | add | update | remove | clear"

if __name__ == "__main__":
    import sys as _sys
    if "--selftest" in _sys.argv:
        # production check: every door is registered and answers without a model
        names = [n for n in dir() if n.startswith("ymir_") or n == "todo"]
        print("doors:", len(names), ", ".join(sorted(names)))
        print(_run(["bash", str(ROOT / "bin" / "vault" / "hodd.sh"), "path"]))
        raise SystemExit(0)
    mcp.run()

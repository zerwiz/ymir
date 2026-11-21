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
def ymir_hermes_list() -> str:
    """Every Hermes session on this machine, with its state in the house's one vocabulary
    (ready · working · blocked: <why> · dead). Read from the runtime's own admissions, never
    from a title. Use it before sending to a session, so a paused one is not woken."""
    return _run(["bash", str(ROOT / "bin" / "seat" / "backend.sh"), "list"], 120)

@mcp.tool()
def ymir_hermes_send(session: str, text: str) -> str:
    """Send one turn to a Hermes session by id prefix or title, through the same door a pane
    is woken through. A paused session is REFUSED with its reason and never replayed: recover
    it first, which shows the lost input before anything is discarded."""
    out = _run(["bash", str(ROOT / "bin" / "seat" / "backend.sh"), "prompt",
                "hermes:%s" % session, text], 900)
    return out or "the door refused the wake (is the session paused? read ymir_hermes_list)"

@mcp.tool()
def ymir_hermes_recover(session: str, yes: bool = False) -> str:
    """Show what a paused Hermes session was carrying when its gateway died, and discard the
    lost turn only when `yes` is true. Without `yes` it prints the lost input and stops —
    a person's turn is not an agent's to throw away."""
    argv = ["bash", str(ROOT / "bin" / "seat" / "backend.sh"), "recover",
            "hermes:%s" % session] + (["--yes"] if yes else [])
    return _run(argv, 300)

@mcp.tool()
def ymir_core_four() -> str:
    """The four dials that decide an agent's outcome, in one read: model, context window
    and compaction thresholds, the prompt surfaces in force, and the tool counts."""
    return _run(["bash", str(ROOT / "bin" / "seat" / "core-four.sh")], 60)

@mcp.tool()
def ymir_pending() -> str:
    """Everything blocked on the operator, in one list: open pull requests, wake lines,
    mail drafts, and the status lines that say 'needs the operator'."""
    return _run(["bash", str(ROOT / "bin" / "seat" / "pending.sh")], 60)

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
# Plan 228 §3 (F2): this face does not own the file; it CALLS `bin/records/todos.sh`,
# the one writer of `<home>/state/todos.json`. Two boards is one board too many.
def _tasks_door() -> Path:
    return ROOT / "bin" / "records" / "todos.sh"

def _door_run(door: Path, *args: str) -> tuple[int, str]:
    """Run the door; return (exit code, text) so a failure is never reported as success."""
    try:
        out = subprocess.run(["bash", str(door), *args], capture_output=True, text=True,
                             timeout=60, cwd=str(ROOT))
        return out.returncode, ((out.stdout or "").strip() or (out.stderr or "").strip())
    except Exception as exc:  # never hang a harness
        return 1, f"failed: {exc}"

def _door_indexes(door: Path) -> list[int]:
    rc, listing = _door_run(door, "list", "--json")
    if rc != 0:
        return []
    import json
    try:
        data = json.loads(listing)
    except Exception:
        return []
    rows = data if isinstance(data, list) else data.get("todos", [])
    return list(range(len(rows)))

@mcp.tool()
def ymir_plan(slug: str = "", title: str = "", action: str = "new", realm: str = "", project: str = "",
              scope: str = "project", owner: str = "", new_shelf: bool = False) -> str:
    """The plan ledger: a plan is filed on the shelf of whoever owns the work.

    action: new (slug+title) · list · next · shelves (every realm and project, and whether it has a shelf).
    scope: project (realm+project; the project is found in any realm, refused if ambiguous or unknown) ·
    realm (a company, owner=<realm>) · machine · personal. new_shelf opens a known project's first shelf.
    """
    argv = ["bash", str(ROOT / "bin" / "records" / "plan.sh"), action]
    if action == "new":
        if not slug or not title:
            return "new needs slug and title"
        argv += [slug, "--title", title]
        if new_shelf:
            argv += ["--new-shelf"]
    if action != "shelves":
        argv += ["--scope", scope or "project"]
        for flag, val in (("--realm", realm), ("--project", project), ("--owner", owner)):
            if val:
                argv += [flag, val]
    return _run(argv, 60)

@mcp.tool()
def ymir_note(path: str, heading: str, body: str) -> str:
    """Append a DATED section to an existing home document (append-only; a correction cites the old entry)."""
    return _run(["bash", str(ROOT / "bin" / "records" / "note.sh"), path, heading, body], 60)

@mcp.tool()
def ymir_header(action: str = "check", path: str = "hodd") -> str:
    """The declared-truth header of home documents: check (list the ones missing one) or apply (add a minimal one)."""
    return _run(["bash", str(ROOT / "bin" / "records" / "header.sh"), action, path], 300)

@mcp.tool()
def ymir_push(message: str, paths: list[str]) -> str:
    """Commit and push NAMED paths in the private home (never git add -A; the vault refuses a secret)."""
    if not message or not paths:
        return "push needs message and paths[]"
    return _run(["bash", str(ROOT / "bin" / "vault" / "push.sh"), message, *paths], 180)

@mcp.tool()
def ymir_seats() -> str:
    """Where the work actually is: every pane in herdr (or tmux), and a shell whose owner is gone named DEAD."""
    return _run(["bash", str(ROOT / "bin" / "seat" / "seats.sh"), "list"], 120)

@mcp.tool()
def ymir_hall(runes: int = 5) -> str:
    """The whole house in one read: the seat, the doors, the queue, the last runes carved."""
    return _run(["bash", str(ROOT / "bin" / "agents" / "hall.sh"), "--runes", str(runes)], 120)

@mcp.tool()
def ymir_arm(action: str = "status", harness: str = "") -> str:
    """The Gná arm, honestly: is the watch loop alive, and can THIS harness arm it? (hook <harness> names its hook.)"""
    if action == "hook":
        return _run(["bash", str(ROOT / "bin" / "pi" / "arm.sh"), "hook", harness or "claude"], 60)
    return _run(["bash", str(ROOT / "bin" / "pi" / "arm.sh"), "status"], 60)

@mcp.tool()
def ymir_place(path: str, why: str, source: str = "") -> str:
    """The ONLY sanctioned way a document enters the home: classify the destination against the
    layout law (refusing what it cannot justify) and move it there. `path` is home-relative."""
    env = dict(os.environ)
    if source:
        env["YMIR_PLACE_SOURCE"] = source
    r = subprocess.run(["python3", str(ROOT / "bin" / "records" / "layout.py"), "place", path, "--why", why],
                       capture_output=True, text=True, timeout=120, env=env, cwd=str(ROOT))
    return (r.stdout or r.stderr).strip()

@mcp.tool()
def ymir_find_home(path: str, note: str = "", sample: str = "") -> str:
    """Where should this file go? The placement oracle: the destination shelf, the reason, and the
    next step. It NEVER moves anything."""
    argv = ["python3", str(ROOT / "bin" / "records" / "layout.py"), "find-home", path]
    if note:
        argv += ["--note", note]
    if sample:
        argv += ["--sample", sample]
    return _run(argv, 60)

@mcp.tool()
def ymir_layout(path: str) -> str:
    """The layout law itself: which shelf a home-relative path belongs to, and why (or the refusal)."""
    return _run(["python3", str(ROOT / "bin" / "records" / "layout.py"), "classify", path], 60)

@mcp.tool()
def ymir_import(sources: list[str], area: str = "", dry_run: bool = True) -> str:
    """Bring material IN from outside the home: classified, then moved with git mv. dry_run proposes."""
    argv = ["python3", str(ROOT / "bin" / "records" / "layout.py"), "import", *sources]
    if area:
        argv += ["--area", area]
    if dry_run:
        argv += ["--dry-run"]
    return _run(argv, 180)

@mcp.tool()
def ymir_index(shelf: str = "hodd") -> str:
    """What is uncalled, empty or stray in a shelf: empty dirs now, and the home's git strays by name."""
    return _run(["python3", str(ROOT / "bin" / "records" / "layout.py"), "index", shelf], 120)

@mcp.tool()
def ymir_dellingr(path: str = "hodd", eldri: int = 90, forn: int = 365) -> str:
    """Dellingr grades a document or shelf: nýr · eldri · forn · safn, from measurable signals only."""
    return _run(["bash", str(ROOT / "bin" / "records" / "grade.sh"), path, "--eldri", str(eldri), "--forn", str(forn)], 180)

@mcp.tool()
def ymir_close_dead(pane: str) -> str:
    """Close a shell whose owner is GONE. Refuses a pane that holds a live agent."""
    return _run(["bash", str(ROOT / "bin" / "seat" / "seats.sh"), "close", pane], 120)

@mcp.tool()
def ymir_telegram(action: str = "list", machine: str = "", text: str = "") -> str:
    """Telegram across the fleet: list the machines (bot id · chat · token ref), check a machine's bot,
    or relay a line from THIS machine into another's chat (a Rune is carved)."""
    if action == "relay":
        if not machine or not text:
            return "relay needs machine and text"
        return _run(["bash", str(ROOT / "bin" / "notify" / "telegram-machines.sh"), "relay", machine, text], 120)
    if action == "me":
        return _run(["bash", str(ROOT / "bin" / "notify" / "telegram-machines.sh"), "me", machine or ""], 90)
    if action == "ear":
        return _run(["bash", str(ROOT / "bin" / "seat" / "hermes-telegram.sh"), "status"], 60)
    return _run(["bash", str(ROOT / "bin" / "notify" / "telegram-machines.sh"), "list"], 60)

# ── the pi-extension doors a non-pi harness was missing (2026-11-10) ─────────────────────
# Each is a thin call to the bin/ door (or the fork script) the pi extension itself calls,
# so the behaviour has one home. Doors that are pi-SESSION state are deliberately absent:
#   context_left        pi's own context gauge — `ymir_context` above reads the number on disk
#   logretta_sit        the council's rounds are orchestrated inside the extension (no CLI yet)
#   whiteboard_tickets, whiteboard_servers   their logic lives in the extension's TS modules
#     (excalidraw_tickets and excalidraw_servers answer as deprecated aliases for one release)
# `skuld_branch_report` IS ported below — its durable write is `skuld-branch-outcome.sh append`;
# the branch's merge note into the Allfather-facing conversation stays the branch extension's.

@mcp.tool()
def skuld_branch_report(task: str, verdict: str, summary: str, wake: str = "", silent: bool = False) -> str:
    """Record one handled fleet event in the durable branch-outcome store (append-only).
    verdict is routine | Allfather; silent is true only for a fleet-wide no-change heartbeat.
    The branch's merge note into the Allfather-facing conversation stays the branch extension's."""
    task, verdict, summary = task.strip(), verdict.strip(), summary.strip()
    if not task or not summary:
        return "skuld_branch_report REFUSED — task and summary are required"
    if verdict not in ("routine", "Allfather"):
        return "skuld_branch_report REFUSED — verdict must be routine or Allfather"
    if silent and not (task == "fleet" and verdict == "routine"):
        return "skuld_branch_report REFUSED — silent is only a fleet-wide routine heartbeat"
    argv = ["bash", str(ROOT / "bin" / "skuld" / "skuld-branch-outcome.sh"), "append",
            "--task", task, "--verdict", verdict, "--summary", summary,
            "--silent", "true" if silent else "false"]
    if wake.strip():
        argv += ["--wake", wake.strip()]
    out = _run(argv, 60)
    return f"branch outcome recorded (seq {out})." if out.strip().isdigit() else out

if __name__ == "__main__":
    import sys as _sys
    if "--selftest" in _sys.argv:
        # production check: every door is registered and answers without a model. The names
        # come from the server's own registry, so a door added under a new prefix is counted.
        try:
            names = [t.name for t in mcp._tool_manager.list_tools()]
        except Exception:
            names = [n for n in dir() if n.startswith("ymir_") or n == "todo"]
        print("doors:", len(names), ", ".join(sorted(names)))
        print(_run(["bash", str(ROOT / "bin" / "vault" / "hodd.sh"), "path"]))
        raise SystemExit(0)
    mcp.run()

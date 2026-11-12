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
def ymir_context(json_output: bool = False) -> str:
    """What THIS agent's context actually holds: used, window, remaining, the compaction
    thresholds, and whether a compaction already fired. Read it before deciding the
    context is out — the number is on disk, and guessing it costs work."""
    out = _run(["bash", str(ROOT / "bin" / "seat" / "context.sh")] + (["--json"] if json_output else []), 60)
    return out


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
def todo(action: str = "list", content: str = "", index: int = -1) -> str:
    """The house task board, shared by every harness: list · add · update · remove · clear."""
    door = _tasks_door()
    if not door.exists():
        return f"the task door is missing: {door} (bin/records/todos.sh)"
    if action == "list":
        return _door_run(door, "list")[1] or "(no todos)"
    if action == "add":
        if not content:
            return "add needs content"
        return _door_run(door, "add", content)[1]
    if action == "update":
        if index < 0:
            return "update needs an index (see `list`)"
        want = (content or "done").strip().lower()
        verb = "done" if want in ("done", "closed", "complete", "completed") else "reopen"
        return _door_run(door, verb, str(index))[1]
    if action == "remove":
        if index < 0:
            return "remove needs an index (see `list`)"
        return _door_run(door, "remove", str(index))[1]
    if action == "clear":
        # From the highest index down, so a removal never shifts a row still to be removed.
        idxs = _door_indexes(door)
        if not idxs:
            return "(no tasks to clear)"
        failed = [str(i) for i in reversed(idxs) if _door_run(door, "remove", str(i))[0] != 0]
        if failed:
            return f"clear failed: could not remove #{', #'.join(failed)}"
        return f"cleared {len(idxs)} task(s)"
    return "action must be list | add | update | remove | clear"


@mcp.tool()
def ymir_plan(slug: str, title: str = "", action: str = "new", realm: str = "", project: str = "ymir",
              scope: str = "project", owner: str = "") -> str:
    """The plan ledger — a plan belongs to whoever owns the work (plan 240).

    scope=project (default, --realm/--project) · realm (a company) · machine (a computer, owner = its hostname)
    · personal (the Allfather's own, under hodd/plans/). action=new creates the NEXT number for THAT shelf with its
    index row; action=list/next accept --all to walk every shelf.
    """
    sh = ["bash", str(ROOT / "bin" / "records" / "plan.sh")]
    if action == "new":
        if not slug or not title:
            return "new needs slug and title"
        argv = sh + ["new", slug, "--title", title, "--project", project, "--scope", scope]
        if realm:
            argv += ["--realm", realm]
        if owner:
            argv += ["--owner", owner]
        return _run(argv, 60)
    argv = sh + [action]
    if scope and scope != "project":
        argv += ["--scope", scope]
    if owner:
        argv += ["--owner", owner]
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
def subagent(agent: str = "", task: str = "") -> str:
    """Dispatch one of Ymir's Eindri figures (kvasir · sindri · bragi · huginn · forseti · mimir …).
    Omit both to list the roster. The behaviour is the errand door (einherjar-spawn.sh)."""
    if not agent:
        return _run(["bash", str(ROOT / "bin" / "agents" / "agent-run.sh"), "--list"], 60)
    return f"dispatch {agent}: run `bin/agents/agent-run.sh {agent} \"{task}\"` (the launch word sets the tone of the errand)"


@mcp.tool()
def well_recall(query: str, k: int = 5) -> str:
    """Drink from the well before acting — Kaia's memory of what was already learned."""
    return ymir_recall(query, k)


@mcp.tool()
def well_observe(lesson: str, tags: str = "") -> str:
    """Water the well after: record what was learned, so the next hand starts ahead."""
    return ymir_remember(lesson, tags)


@mcp.tool()
def gna_watch_arm() -> str:
    """Pi's own name for the arm: start the first required watcher cycle — or read why it cannot be armed."""
    return ymir_arm("status")


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
#   excalidraw_tickets, excalidraw_servers  their logic lives in the extension's TS modules
# `skuld_branch_report` IS ported below — its durable write is `skuld-branch-outcome.sh append`;
# the branch's merge note into the Allfather-facing conversation stays the branch extension's.


@mcp.tool()
def brokk_branch_outcomes(recent: int = 20) -> str:
    """Read the supervision branch's durable outcome store: what fleet events it handled, each verdict and summary."""
    n = str(max(1, int(recent or 20)))
    out = _run(["bash", str(ROOT / "bin" / "skuld" / "skuld-branch-outcome.sh"), "list", "--recent", n], 60)
    return "(no branch outcomes recorded)" if out == "(no output)" else out


@mcp.tool()
def skuld_ticket(state: str = "", limit: int = 20) -> str:
    """The tickets: what is queued, in flight, or closed — read from the DERIVED work queue (bin/gates/queue.sh)."""
    q = _run(["bash", str(ROOT / "bin" / "gates" / "queue.sh"), "--check"], 120)
    lines = [l for l in q.splitlines() if l.startswith("| ")]
    head = next((l for l in lines if l.startswith("| # ")), None)
    want = state.lower().strip()
    body = [l for l in lines if l != head and (not want or want in l.lower())]
    rows = []
    for l in body[: max(1, int(limit or 20))]:
        c = [x.strip() for x in l.split("|")]
        if len(c) < 4:
            continue
        rows.append(f'  "{c[3] or c[2]}","{c[2][:78]}"')
    return "\n".join([f"tickets[{len(rows)}]{{state,what}}:", *rows, "",
                      "derived from register.md + questions.md — a queue that is authored rots."])


@mcp.tool()
def skuld_plan(topic: str = "", realm: str = "", project: str = "ymir") -> str:
    """What is planned: the plan ledger in the home (one row per plan file, with its headline). Omit topic for the shelf."""
    shelf = os.environ.get("YMIR_PLAN_DIR", "")
    if not shelf:
        base = _home() / "svartalfaheim" / (realm or "whynotproductions")
        cands = [base / "projects" / project / "plans", base / "workspace" / project / "plans"]
        shelf = str(next((c for c in cands if c.is_dir()), cands[0]))
    d = Path(shelf)
    def _num(n: str) -> int:
        h = n.split("-")[0]
        return int(h) if h.isdigit() else 10**9
    names = sorted((p.name for p in d.glob("*.md")), key=lambda n: (_num(n), n)) if d.is_dir() else []
    t = topic.lower().strip()
    hit = [n for n in names if not t or t in n.lower()]
    if not hit:
        return f'no plan matches{f" {topic!r}" if t else ""} in {shelf}\nthe shelf holds: {len(names)} files'
    rows = [f"plans[{len(hit)}]{{file,headline}}:"]
    for n in hit:
        try:
            lines = (d / n).read_text(errors="replace").splitlines()
            head = (lines[2] if len(lines) > 2 else (lines[0] if lines else ""))[:88]
        except OSError:
            head = ""
        rows.append(f'  "{n}","{head.replace(chr(34), chr(39))}"')
    rows += ["", "state and what is owed: bin/gates/queue.sh --check · why it exists: ymir_rule <topic>"]
    return "\n".join(rows)


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


@mcp.tool()
def constellation_list() -> str:
    """The Ymir mesh: every peer in the agent-card registry, with its endpoint and skills (invalid cards are named)."""
    return _run(["bash", str(ROOT / "bin" / "bridge" / "constellation.sh"), "list"], 60)


@mcp.tool()
def constellation_card(peer: str) -> str:
    """One peer's agent card exactly as the registry holds it. Read-only."""
    if not peer.strip():
        return "constellation_card REFUSED — peer is required"
    return _run(["bash", str(ROOT / "bin" / "bridge" / "constellation.sh"), "show", peer.strip()], 60)


@mcp.tool()
def constellation_ask(peer: str, skill: str) -> str:
    """Check whether a peer declares a skill and what grant a call would need. No call is ever sent:
    a call needs a grant (per pair, per skill) and a short-lived skill-scoped token."""
    peer, skill = peer.strip(), skill.strip()
    if not peer or not skill:
        return "constellation_ask REFUSED — both peer and skill are required"
    door = str(ROOT / "bin" / "bridge" / "constellation.sh")
    card = _run(["bash", door, "show", peer], 60)
    grants = _run(["bash", door, "grants", "--peer", peer], 60)
    declared = skill in card
    return "\n".join([
        f'constellation_ask REFUSED — no call is sent to "{peer}" for skill "{skill}".',
        f"the peer {'declares' if declared else 'does NOT declare'} that skill in its card.",
        f"a call needs a grant: bin/bridge/constellation.sh grant {peer} {skill}, then a token from `mint`.",
        "", "grants on record for this peer:", grants,
    ])


@mcp.tool()
def logretta_stack() -> str:
    """The council's roster: is the stack seated on this machine, and does it validate?"""
    return _run(["bash", str(ROOT / "bin" / "pi" / "logretta-ensure.sh"), "status"], 60)


def _excalidraw_root() -> Path:
    return Path(os.environ.get("EXCALIDRAW_ROOT") or (Path.home() / "CodeP" / "excalidraw"))


@mcp.tool()
def excalidraw_diagram(action: str = "create", spec: dict | None = None, out: str = "",
                       path: str = "", columns: int = 0) -> str:
    """Write an .excalidraw scene from a spec ({nodes:[{id,label?,shape?}], edges?}) or describe one (action=describe, path)."""
    root = _excalidraw_root()
    script = root / "server" / "diagram" / "write.mjs"
    if not script.exists():
        return f"no diagram writer at {script} — set EXCALIDRAW_ROOT to the fork's checkout."
    if action == "describe":
        if not path:
            return "action=describe needs a path."
        return _run(["node", str(script), "--describe", path], 60)
    if not spec or not isinstance(spec.get("nodes"), list):
        return "action=create needs spec.nodes — an array of {id, label?, shape?}."
    dest = out or str(root / "diagram.excalidraw")
    argv = ["node", str(script), "--out", dest] + (["--columns", str(columns)] if columns else [])
    try:
        import json as _json
        p = subprocess.run(argv, input=_json.dumps(spec), capture_output=True, text=True, timeout=60)
        text = "\n".join(x for x in ((p.stdout or "").strip(), (p.stderr or "").strip()) if x) or "(no output)"
        return text if p.returncode == 0 else f"{text}\n(exit {p.returncode})"
    except Exception as exc:
        return f"failed: {exc}"


@mcp.tool()
def excalidraw_app(action: str = "status") -> str:
    """The Excalidraw desktop app over its local dev server: status (default), start, or stop."""
    root = _excalidraw_root()
    if action == "status":
        import urllib.request
        try:
            with urllib.request.urlopen("http://127.0.0.1:7311/", timeout=1.2) as r:
                return f"the app's dev server answers on :7311 ({r.status})."
        except Exception as exc:
            return f"the app is not up on :7311 ({exc})."
    if action not in ("start", "stop"):
        return "action must be status | start | stop"
    script = root / "scripts" / f"{action}.sh"
    if not script.exists():
        return f"missing {script} — set EXCALIDRAW_ROOT to the fork's checkout."
    subprocess.Popen([str(script)], cwd=str(root), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    return f"{action}.sh launched (detached). Check with action=status in a few seconds."


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

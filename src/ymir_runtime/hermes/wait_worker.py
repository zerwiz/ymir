"""`wait-worker` — a finished herdr worker wakes the Hermes session that sent it (plan 317 §5, slice 9).

WHY. 2026-11-18, measured: a `no_agent` cron delivers a NOTE, never a turn, so eight finished
workers were announced and none was acted on; and the stop-gap watcher, a background process inside
an agent's session, was SIGKILLed after ~1,085 s. So the waiter does not live in the agent's session:

    wait-worker                 start a SUPERVISED waiter (a transient systemd user unit) and return.
                                It survives the session that started it; when a worker finishes it
                                delivers a TURN into that session by Hermes' own road
                                (`hermes chat --resume <id> -q … -Q`, the descriptor's `inject:`).
    wait-worker --foreground    the waiter itself (what the unit runs); prints to the journal.
    wait-worker --once [--cron] check now, print who finished, never wait; with --cron print nothing
                                when nothing finished, so a quiet Hermes cron tick delivers nothing.

A worker counts as FINISHED only when herdr says it is not `working` AND its handoff exists —
idle is not done (a worker that read its brief and stopped is idle too). The handoff is read from the
pane's own working tree (`<cwd>/docs/handoffs/<name>.md`) or named with `--handoff`; no product's
home is assumed. Each consumer keeps its own seen-set (`--scope`), so the cron note and a session's
waiter never steal each other's finish. Panes are NEVER closed here.

Delivery is careful, because a turn is the operator's session: a session whose last admission is
`unknown` is paused (a lost turn) and is never written into; a session mid-turn (`queued`/`started`)
is waited for; `hermes chat` exit 3 (paused) is recorded and retried, never forced.
"""

from __future__ import annotations

import json
import os
import re
import sqlite3
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping, Sequence

from . import common as C

DEFAULT_POLL = 60
DEFAULT_LIMIT = 6 * 3600
DEFAULT_PREFIX = "w-"
STAMP = "[from script ymir wait-worker]"
# Variables a supervised waiter carries over from the session that started it.
CARRY = ("PATH", "HOME", "HERMES_HOME", "HERMES_CONFIG", "HERMES_BIN", "YMIR_HERDR", "YMIR_HERMES_STATE",
         "XDG_STATE_HOME", "YMIR_RUNTIME_DIR", "YMIR_WAIT_PREFIX", "HERMES_TURN_TIMEOUT", "LANG")


@dataclass(frozen=True)
class Finished:
    name: str
    status: str
    handoff: Path
    key: str

    def line(self) -> str:
        return f"{self.name} finished ({self.status}) — handoff: {self.handoff}"


# ── herdr, read once per poll ───────────────────────────────────────────────────────────────────

def herdr_agents(env: Mapping[str, str]) -> list[dict]:
    r = C.run([C.herdr_bin(env), "agent", "list"], timeout=30, env=env)
    if not r.ok:
        raise C.HermesError(f"herdr did not answer: {(r.err or r.out).strip()[:200]}",
                            "is herdr running? `herdr agent list`")
    try:
        doc = json.loads(r.out)
    except ValueError as exc:
        raise C.HermesError(f"herdr agent list is not JSON: {r.out[:120]!r}", "update herdr") from exc
    return list(((doc.get("result") or {}).get("agents")) or [])


def find_handoff(agent: Mapping, explicit: Mapping[str, Path] | None = None) -> Path | None:
    name = str(agent.get("name") or "")
    if explicit and name in explicit:
        return explicit[name] if explicit[name].exists() else None
    for base in (agent.get("cwd"), agent.get("foreground_cwd")):
        if not base:
            continue
        p = Path(str(base)) / "docs" / "handoffs" / f"{name}.md"
        if p.exists():
            return p
    return None


def _key(name: str, handoff: Path) -> str:
    try:
        mtime = int(handoff.stat().st_mtime)
    except OSError:
        mtime = 0
    return f"{name}|{handoff}|{mtime}"


def survey(agents: Sequence[Mapping], *, prefix: str, names: Sequence[str],
           handoffs: Mapping[str, Path] | None = None) -> tuple[list[Finished], list[str]]:
    """Every finished worker (seen or not), and the names still working."""
    done: list[Finished] = []
    working: list[str] = []
    for a in agents:
        name = str(a.get("name") or "")
        if names and name not in names:
            continue
        if not names and not name.startswith(prefix):
            continue
        status = str(a.get("agent_status") or "unknown")
        if status == "working":
            working.append(name)
            continue
        h = find_handoff(a, handoffs)
        if h is not None:
            done.append(Finished(name, status, h, _key(name, h)))
    return done, sorted(working)


# ── the seen-set, one per consumer ──────────────────────────────────────────────────────────────

def _scope_file(env: Mapping[str, str], scope: str) -> Path:
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", scope)[:80] or "default"
    return C.state_dir(env) / "wait-worker" / f"seen.{safe}.json"


def load_seen(env: Mapping[str, str], scope: str) -> set[str]:
    return set(C.load_json(_scope_file(env, scope), []))


def save_seen(env: Mapping[str, str], scope: str, seen: set[str]) -> None:
    C.write_atomic(_scope_file(env, scope), json.dumps(sorted(seen), indent=1) + "\n")


def message(done: Sequence[Finished], working: Sequence[str]) -> str:
    lines = [f"{STAMP} {d.line()}" for d in done]
    lines.append(f"still working: {', '.join(working) or 'nobody'}")
    lines.append("Read the handoff, review the work, and decide what is next.")
    return "\n".join(lines)


# ── --once: the cron's note ─────────────────────────────────────────────────────────────────────

def once(env: Mapping[str, str], *, scope: str, cron: bool, prefix: str, names: Sequence[str],
         out: Callable[[str], None] = print) -> int:
    done, working = survey(herdr_agents(env), prefix=prefix, names=names)
    seen = load_seen(env, scope)
    new = [d for d in done if d.key not in seen]
    if new:
        for d in new:
            out(d.line())
        out(f"still working: {', '.join(working) or 'nobody'}")
        save_seen(env, scope, seen | {d.key for d in new})
    elif not cron:
        out(f"nobody new finished; working: {', '.join(working) or 'nobody'}")
    return 0


# ── delivery: a turn in the session that asked ──────────────────────────────────────────────────

def admission(env: Mapping[str, str], session: str) -> str:
    """The session's last admission status ('' when none), read-only. Raises when the store is unreadable."""
    db = C.hermes_home(env) / "state.db"
    if not db.exists():
        return ""
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=5)
        try:
            row = con.execute("SELECT status FROM session_admissions WHERE target_session_id=?"
                              " ORDER BY seq DESC LIMIT 1", (session,)).fetchone()
        finally:
            con.close()
    except sqlite3.Error as exc:
        raise C.HermesError(f"hermes state.db unreadable: {exc}", "hermes doctor") from exc
    return str(row[0]) if row and row[0] else ""


def deliver(env: Mapping[str, str], session: str, text: str) -> tuple[bool, str]:
    """One turn in `session`. (delivered, why-not). Never into a paused session, never mid-turn."""
    try:
        state = admission(env, session)
    except C.HermesError as exc:
        return False, str(exc)
    if state == "unknown":
        return False, "paused: the session carries a lost turn (recover it in Hermes first)"
    if state in ("queued", "started"):
        return False, "busy: the session is mid-turn"
    r = C.run([C.hermes_bin(env), "chat", "--resume", session, "-q", text, "-Q"],
              timeout=float(env.get("HERMES_TURN_TIMEOUT") or 600), env=env)
    if r.rc == 0:
        return True, "delivered"
    if r.rc == 3:
        return False, "paused: hermes chat exit 3"
    return False, f"hermes chat exit {r.rc}: {(r.err or r.out).strip()[-200:]}"


def foreground(env: Mapping[str, str], *, session: str, prefix: str, names: Sequence[str],
               poll: float, limit: float, include_finished: bool,
               handoffs: Mapping[str, Path] | None = None,
               out: Callable[[str], None] = print,
               sleep: Callable[[float], None] = time.sleep,
               deliver_fn: Callable[[Mapping[str, str], str, str], tuple[bool, str]] = deliver,
               agents_fn: Callable[[Mapping[str, str]], list[dict]] = herdr_agents) -> int:
    """The waiter. Exit 0 when the turn is delivered (or the wait ran out, said so); 1 on refusal."""
    scope = f"session-{session}"
    seen = load_seen(env, scope)
    if not include_finished:
        done, _ = survey(agents_fn(env), prefix=prefix, names=names, handoffs=handoffs)
        base = {d.key for d in done}
        if base - seen:
            out(f"baseline: {len(base - seen)} worker(s) already finished before this wait — not announced")
        seen |= base
        save_seen(env, scope, seen)
    started = time.monotonic()
    pending: list[Finished] = []
    working: list[str] = []
    out(f"waiting for {', '.join(names) or prefix + '*'} — the finish lands in session {session}")
    while True:
        try:
            done, working = survey(agents_fn(env), prefix=prefix, names=names, handoffs=handoffs)
        except C.HermesError as exc:
            out(f"herdr: {exc} — retrying")
            done = []
        for d in done:
            if d.key not in seen and d.key not in {p.key for p in pending}:
                out(f"finished: {d.line()}")
                pending.append(d)
        if pending:
            ok, why = deliver_fn(env, session, message(pending, working))
            if ok:
                seen |= {p.key for p in pending}
                save_seen(env, scope, seen)
                out(f"delivered: a turn in {session} for {', '.join(p.name for p in pending)}")
                return 0
            out(f"not yet delivered ({why}) — retrying in {poll:g}s")
        elif names and not working and not done:
            out(f"none of {', '.join(names)} is working and none has a handoff — check the panes")
        if time.monotonic() - started > limit:
            out(f"gave up after {limit:g}s; undelivered: {', '.join(p.name for p in pending) or 'none'}; "
                f"working: {', '.join(working) or 'nobody'}")
            return 1 if pending else 0
        sleep(poll)


# ── the supervised start ────────────────────────────────────────────────────────────────────────

def unit_name(session: str) -> str:
    tail = re.sub(r"[^A-Za-z0-9]", "", session)[-12:] or "nosession"
    return f"ymir-wait-worker-{tail}-{C.stamp().lower()}"


def supervise(env: Mapping[str, str], *, session: str, prefix: str, names: Sequence[str], poll: float,
              limit: float, include_finished: bool, handoffs: Mapping[str, Path] | None = None,
              out: Callable[[str], None] = print) -> int:
    """Start the waiter as a transient systemd user unit — not a child of the agent's session."""
    unit = unit_name(session)
    src = str(C.tree_root() / "src")
    argv = ["systemd-run", "--user", "--unit", unit, "--collect", "--quiet",
            "--property", f"RuntimeMaxSec={int(limit) + 900}",
            "--setenv", f"PYTHONPATH={src}", "--setenv", "PYTHONUNBUFFERED=1"]
    for k in CARRY:
        if env.get(k):
            argv += ["--setenv", f"{k}={env[k]}"]
    argv += ["--", sys.executable, "-m", "ymir_runtime.hermes", "wait-worker", "--foreground",
             "--session", session, "--prefix", prefix, "--poll", f"{poll:g}", "--limit", f"{limit:g}"]
    for n in names:
        argv += ["--worker", n]
    for n, h in (handoffs or {}).items():
        argv += ["--handoff", f"{n}={h}"]
    if include_finished:
        argv.append("--include-finished")
    r = C.run(argv, timeout=30, env=env)
    if not r.ok:
        raise C.HermesError(f"systemd-run refused the waiter: {(r.err or r.out).strip()[:200]}",
                            "is the user manager running? `systemctl --user status`")
    record = C.state_dir(env) / "wait-worker" / f"{unit}.json"
    C.write_atomic(record, json.dumps({"unit": unit, "session": session, "workers": list(names),
                                       "prefix": prefix, "started": C.now_iso()}, indent=1) + "\n")
    out(f"supervised: unit {unit} waits for {', '.join(names) or prefix + '*'}; "
        f"the finish lands in session {session} as a turn")
    out(f"follow it: journalctl --user -u {unit} -f")
    return 0


def resolve_session(env: Mapping[str, str], given: str) -> str:
    session = given or env.get("HERMES_SESSION_ID", "")
    if not session:
        raise C.HermesError("no session to wake: this is not a Hermes session and no --session was given",
                            "run it from a Hermes session, or pass --session <id>")
    return session


def parse_handoffs(values: Sequence[str]) -> dict[str, Path]:
    out: dict[str, Path] = {}
    for v in values:
        if "=" not in v:
            raise C.HermesError(f"--handoff wants NAME=PATH, got {v!r}", "--handoff w-name=/path/to/handoff.md")
        n, p = v.split("=", 1)
        out[n] = Path(os.path.expanduser(p))
    return out

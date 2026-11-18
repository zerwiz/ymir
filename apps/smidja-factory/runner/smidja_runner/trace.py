"""The trace, read and steered — the same moves the viewer makes, without needing it up.

Reads open the db read-only (WAL: a reader never blocks a run). The few writes are
the viewer's own: finalize a stopped run, mark runs aborted on an emergency stop.
Signals go children first, then the run, exactly as `/api/sessions/:id/stop` does,
and a pid is signalled only when its /proc cmdline still matches the recorded
command — a recycled pid is never killed by mistake.
"""

from __future__ import annotations

import os
import signal
import sqlite3
from datetime import datetime, timezone
from pathlib import Path


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def connect(db: Path, write: bool = False) -> sqlite3.Connection:
    if not db.exists():
        raise FileNotFoundError(f"no trace at {db} — no run has been recorded on this machine yet")
    uri = f"file:{db}" + ("" if write else "?mode=ro")
    conn = sqlite3.connect(uri, uri=True, timeout=10)
    conn.row_factory = sqlite3.Row
    return conn


def rows(conn: sqlite3.Connection, sql: str, args: tuple = ()) -> list[dict]:
    return [dict(r) for r in conn.execute(sql, args).fetchall()]


def table_exists(conn: sqlite3.Connection, name: str) -> bool:
    return conn.execute("select 1 from sqlite_master where type='table' and name=?",
                        (name,)).fetchone() is not None


def sessions(db: Path, limit: int = 10, include_archived: bool = False) -> list[dict]:
    with connect(db) as c:
        where = "" if include_archived else "where coalesce(archived,0)=0"
        return rows(c, f"select smidja_id, smidja_name, status, substr(request,1,120) as request, "
                       f"engineer, started_at, ended_at, total_tokens, round(total_cost,4) as total_cost "
                       f"from sessions {where} order by started_at desc limit ?", (limit,))


def session(db: Path, smidja_id: str) -> dict | None:
    with connect(db) as c:
        r = rows(c, "select * from sessions where smidja_id=?", (smidja_id,))
        return r[0] if r else None


def phases(db: Path, smidja_id: str) -> list[dict]:
    with connect(db) as c:
        return rows(c, "select seq, name, kind, owner, status, attempt, retries, error "
                       "from phases where smidja_id=? order by seq", (smidja_id,))


def events(db: Path, smidja_id: str, after: int = 0, limit: int = 25) -> list[dict]:
    with connect(db) as c:
        if after:
            return rows(c, "select rowid, type, name, tokens, started_at, substr(payload_json,1,400) as payload "
                           "from events where smidja_id=? and rowid>? order by rowid limit ?",
                        (smidja_id, after, limit))
        out = rows(c, "select rowid, type, name, tokens, started_at, substr(payload_json,1,400) as payload "
                      "from events where smidja_id=? order by rowid desc limit ?", (smidja_id, limit))
        return list(reversed(out))


def gates(db: Path, smidja_id: str) -> list[dict]:
    with connect(db) as c:
        return rows(c, "select g.gate, g.passed, g.attempt, p.name as phase, "
                       "substr(g.violations_json,1,600) as violations "
                       "from gate_results g left join phases p on p.phase_id=g.phase_id "
                       "where g.smidja_id=? order by g.id", (smidja_id,))


def envelopes(db: Path, smidja_id: str) -> list[dict]:
    with connect(db) as c:
        return rows(c, "select agent, output_type, valid, attempt, created_at, "
                       "substr(payload_json,1,2000) as payload from envelopes "
                       "where smidja_id=? order by created_at", (smidja_id,))


def tool_calls(db: Path, smidja_id: str) -> dict[str, int]:
    """Tool calls per agent — the evidence an agent did work, not just claimed it."""
    with connect(db) as c:
        out: dict[str, int] = {}
        for r in rows(c, "select p.owner as agent, count(*) as n from events e "
                         "left join phases p on p.phase_id=e.phase_id "
                         "where e.smidja_id=? and e.type in ('tool_call','tool_execution_end') "
                         "group by p.owner", (smidja_id,)):
            out[r["agent"] or "?"] = r["n"]
        return out


def _alive(pid: int, command: str) -> bool:
    try:
        cmdline = Path(f"/proc/{pid}/cmdline").read_bytes().replace(b"\0", b" ").decode(errors="replace")
    except OSError:
        return False
    if not command:
        return True
    head = command.split()[0] if command.split() else ""
    return bool(head) and Path(head).name.split(".")[0] in cmdline


def processes(db: Path, smidja_id: str | None = None, live_only: bool = True) -> list[dict]:
    with connect(db) as c:
        if smidja_id:
            out = rows(c, "select id, smidja_id, kind, name, pid, command, started_at from processes "
                          "where smidja_id=? and ended_at is null order by id", (smidja_id,))
        else:
            out = rows(c, "select id, smidja_id, kind, name, pid, command, started_at from processes "
                          "where ended_at is null order by id")
    if live_only:
        out = [p for p in out if p["pid"] and _alive(int(p["pid"]), p["command"] or "")]
    return out


def signal_run(db: Path, smidja_id: str, sig: int, agents_only: bool = False) -> list[int]:
    procs = processes(db, smidja_id)
    order = [p for p in procs if p["kind"] == "agent"]
    if not agents_only:
        order += [p for p in procs if p["kind"] == "smidja"]
    sent = []
    for p in order:
        try:
            os.kill(int(p["pid"]), sig)
            sent.append(int(p["pid"]))
        except OSError:
            pass
    return sent


def finalize(db: Path, smidja_id: str, status: str = "fail") -> None:
    """Close a run that has no live process left (the viewer's finalizeStopped)."""
    if processes(db, smidja_id):
        return
    with connect(db, write=True) as c:
        stamp = now_iso()
        c.execute("update processes set ended_at=? where smidja_id=? and ended_at is null", (stamp, smidja_id))
        c.execute("update sessions set status=?, ended_at=coalesce(ended_at, ?) "
                  "where smidja_id=? and status='running'", (status, stamp, smidja_id))


def stop(db: Path, smidja_id: str) -> dict:
    if not session(db, smidja_id):
        raise LookupError(f"no such run: {smidja_id}")
    pids = signal_run(db, smidja_id, signal.SIGTERM)
    finalize(db, smidja_id)
    return {"smidja_id": smidja_id, "stopped": len(pids), "pids": pids}


def emergency(db: Path) -> dict:
    """Every live smithy process, killed hard, and every running run marked aborted."""
    procs = processes(db) if db.exists() else []
    killed = []
    for p in sorted(procs, key=lambda p: 0 if p["kind"] == "agent" else 1):
        try:
            os.kill(int(p["pid"]), signal.SIGKILL)
            killed.append(int(p["pid"]))
        except OSError:
            pass
    aborted = 0
    if db.exists():
        with connect(db, write=True) as c:
            stamp = now_iso()
            aborted = c.execute("update sessions set status='aborted', ended_at=coalesce(ended_at, ?) "
                                "where status='running'", (stamp,)).rowcount
            c.execute("update processes set ended_at=? where ended_at is null", (stamp,))
    return {"killed": killed, "aborted_runs": aborted}

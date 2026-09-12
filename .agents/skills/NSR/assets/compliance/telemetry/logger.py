#!/usr/bin/env python3
# telemetry logger: SQLite observability.
# One data path: agents write to SQLite (runs/events); readers poll SQLite.
import argparse
import json
import pathlib
import sqlite3
import sys
import time
import uuid


def find_root():
    for parent in pathlib.Path(__file__).resolve().parents:
        if (parent / ".agents").is_dir():
            return parent
    raise SystemExit("error: not in a NorthStar repo (no .agents/ upward)")


ROOT = find_root()
DB = ROOT / ".compliance" / "telemetry" / "runs.db"

SCHEMA = """
CREATE TABLE IF NOT EXISTS runs (
  id TEXT PRIMARY KEY,
  ts REAL NOT NULL,
  phase TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'success',
  tokens INTEGER NOT NULL DEFAULT 0,
  latency_ms REAL NOT NULL DEFAULT 0,
  tool_invocations INTEGER NOT NULL DEFAULT 0,
  cost_usd REAL NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT,
  ts REAL NOT NULL,
  type TEXT NOT NULL,
  detail TEXT
);
"""


def connect():
    DB.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(str(DB))
    con.executescript(SCHEMA)
    return con


def cmd_log(args):
    run_id = args.run_id or uuid.uuid4().hex[:12]
    con = connect()
    con.execute(
        "INSERT INTO runs (id, ts, phase, status, tokens, latency_ms, tool_invocations, cost_usd) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (run_id, time.time(), args.phase, args.status, args.tokens,
         args.latency_ms, args.tool_invocations, args.cost),
    )
    for ev in args.event or []:
        etype, _, detail = ev.partition(":")
        con.execute(
            "INSERT INTO events (run_id, ts, type, detail) VALUES (?, ?, ?, ?)",
            (run_id, time.time(), etype, detail),
        )
    con.commit()
    print("[telemetry] logged %s (%s): tokens=%d latency=%.1fms tools=%d cost=$%.4f"
          % (args.phase, run_id, args.tokens, args.latency_ms, args.tool_invocations, args.cost))
    con.close()


def cmd_query(args):
    con = connect()
    rows = con.execute(
        "SELECT id, ts, phase, status, tokens, latency_ms, tool_invocations, cost_usd "
        "FROM runs ORDER BY ts DESC LIMIT ?",
        (args.last,),
    ).fetchall()
    for row in rows:
        print(json.dumps(dict(zip(
            ["run_id", "ts", "phase", "status", "tokens", "latency_ms", "tool_invocations", "cost_usd"],
            row))))
    con.close()


def main():
    p = argparse.ArgumentParser(description="WayOfNorthStar telemetry logger (SQLite)")
    sub = p.add_subparsers(dest="cmd")
    logp = sub.add_parser("log", help="write a run/event record")
    logp.add_argument("--run-id")
    logp.add_argument("--phase", default="debug")
    logp.add_argument("--status", default="success")
    logp.add_argument("--tokens", type=int, default=0)
    logp.add_argument("--latency-ms", type=float, default=0.0)
    logp.add_argument("--tool-invocations", type=int, default=0)
    logp.add_argument("--cost", type=float, default=0.0)
    logp.add_argument("--event", action="append", help="type[:detail]")
    qp = sub.add_parser("query", help="read recent runs (readers poll SQLite)")
    qp.add_argument("--last", type=int, default=10)
    args = p.parse_args()
    if args.cmd == "log":
        cmd_log(args)
        return 0
    if args.cmd == "query":
        cmd_query(args)
        return 0
    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
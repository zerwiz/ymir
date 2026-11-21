#!/usr/bin/env python3
"""events.py — the one writer of the events store (plan 333 phase 1, plan 332).

Every system that has something happen writes ONE row here, and nothing else writes
events. Rows are JSON lines in day files: <state>/events/YYYY-MM-DD.jsonl.

Row schema (all seven fields are required, strings):
  ts        ISO-8601 time with offset (default: now)
  source    who says it            [a-z0-9][a-z0-9_.-]*   e.g. cron, garmr
  kind      what sort of event     [a-z0-9][a-z0-9_.-]*   e.g. job-failed, finding
  subject   what it is about       one line, up to 200 chars
  severity  INFO | MEDIUM | HIGH | CRITICAL
  key       dedupe key; the same key on the same day is written once
  body      the detail, up to 4000 chars (may be empty)

  events.py append --source S --kind K --subject T [--severity INFO] [--key K] [--body B] [--ts TS]
  events.py tail   [-n 20] [--source S] [--kind K] [--min-severity HIGH]
  events.py search <text> [--days 7] [--source S] [--kind K] [--min-severity MEDIUM]

Exit: append 0 written or duplicate · 1 refused (invalid) · 2 usage/IO.
The state dir is $YMIR_EVENTS_DIR, else <state>/events where <state> is
$YMIR_STATE_DIR, else <home>/state (home from $YMIR_HOME).
"""
from __future__ import annotations

import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
import re
import sys

SEVERITIES = ("INFO", "MEDIUM", "HIGH", "CRITICAL")
FIELDS = ("ts", "source", "kind", "subject", "severity", "key", "body")
_NAME = re.compile(r"^[a-z0-9][a-z0-9_.-]{0,63}$")
_TS = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")
MAX_SUBJECT, MAX_BODY, MAX_KEY = 200, 4000, 200


class Invalid(ValueError):
    pass


def events_dir() -> str:
    env = os.environ.get("YMIR_EVENTS_DIR")
    if env:
        return os.path.expanduser(env)
    state = os.environ.get("YMIR_STATE_DIR")
    if not state:
        home = os.environ.get("YMIR_HOME")
        if not home:
            raise SystemExit("events: the home is unresolved — set YMIR_HOME, YMIR_STATE_DIR or YMIR_EVENTS_DIR")
        state = os.path.join(os.path.expanduser(home), "state")
    return os.path.join(os.path.expanduser(state), "events")


def now_iso() -> str:
    return dt.datetime.now().astimezone().replace(microsecond=0).isoformat()


def derive_key(row: dict) -> str:
    raw = "|".join(str(row.get(f, "")) for f in ("source", "kind", "subject", "body"))
    return "auto:" + hashlib.sha1(raw.encode("utf-8")).hexdigest()[:16]


def validate(row: dict) -> dict:
    """Return the cleaned row or raise Invalid naming the first fault."""
    if not isinstance(row, dict):
        raise Invalid("a row must be an object")
    unknown = sorted(set(row) - set(FIELDS))
    if unknown:
        raise Invalid("unknown field(s): " + ", ".join(unknown))
    out = dict(row)
    out.setdefault("ts", now_iso())
    out["severity"] = str(out.get("severity") or "INFO").upper()
    out.setdefault("body", "")
    for f in ("source", "kind", "subject", "body"):
        if f in ("body",):
            continue
        if f not in out or not isinstance(out[f], str) or not out[f].strip():
            raise Invalid(f"{f} is required")
    if not isinstance(out["body"], str):
        raise Invalid("body must be a string")
    if not isinstance(out["ts"], str) or not _TS.match(out["ts"]):
        raise Invalid("ts must be ISO-8601, e.g. 2026-11-21T12:00:00+00:00")
    for f in ("source", "kind"):
        if not _NAME.match(out[f]):
            raise Invalid(f"{f} must match [a-z0-9][a-z0-9_.-]* (max 64)")
    if out["severity"] not in SEVERITIES:
        raise Invalid("severity must be one of " + "|".join(SEVERITIES))
    out["subject"] = " ".join(out["subject"].split())
    if len(out["subject"]) > MAX_SUBJECT:
        raise Invalid(f"subject is over {MAX_SUBJECT} characters")
    if len(out["body"]) > MAX_BODY:
        raise Invalid(f"body is over {MAX_BODY} characters")
    key = out.get("key")
    if key is None or (isinstance(key, str) and not key.strip()):
        out["key"] = derive_key(out)
    elif not isinstance(key, str) or len(key) > MAX_KEY or "\n" in key:
        raise Invalid(f"key must be one line of at most {MAX_KEY} characters")
    return {f: out[f] for f in FIELDS}


def _day_file(ts: str) -> str:
    return os.path.join(events_dir(), ts[:10] + ".jsonl")


def append(row: dict) -> tuple[str, dict]:
    """Write one row. Returns ("written"|"duplicate", row)."""
    row = validate(row)
    path = _day_file(row["ts"])
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a+", encoding="utf-8") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        handle.seek(0)
        for line in handle:
            try:
                if json.loads(line).get("key") == row["key"]:
                    return "duplicate", row
            except ValueError:
                continue
        handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
        handle.flush()
    return "written", row


def _rows(days: int | None):
    d = events_dir()
    if not os.path.isdir(d):
        return
    files = sorted(f for f in os.listdir(d) if re.match(r"^\d{4}-\d{2}-\d{2}\.jsonl$", f))
    if days is not None:
        cutoff = (dt.date.today() - dt.timedelta(days=max(days - 1, 0))).isoformat()
        files = [f for f in files if f[:10] >= cutoff]
    for f in files:
        with open(os.path.join(d, f), encoding="utf-8") as handle:
            for line in handle:
                try:
                    yield json.loads(line)
                except ValueError:
                    continue


def _match(row: dict, source, kind, min_sev) -> bool:
    if source and row.get("source") != source:
        return False
    if kind and row.get("kind") != kind:
        return False
    if min_sev and SEVERITIES.index(row.get("severity", "INFO")) < SEVERITIES.index(min_sev):
        return False
    return True


def _line(r: dict) -> str:
    return f'{r["ts"]}  {r["severity"]:<8} {r["source"]}/{r["kind"]}  {r["subject"]}'


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="events.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("append")
    for f in ("source", "kind", "subject", "severity", "key", "body", "ts"):
        a.add_argument("--" + f)
    t = sub.add_parser("tail")
    t.add_argument("-n", type=int, default=20)
    s = sub.add_parser("search")
    s.add_argument("text")
    s.add_argument("--days", type=int, default=7)
    for p in (t, s):
        p.add_argument("--source")
        p.add_argument("--kind")
        p.add_argument("--min-severity", choices=SEVERITIES)
        p.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    if args.cmd == "append":
        row = {f: getattr(args, f) for f in FIELDS if getattr(args, f) is not None}
        try:
            verdict, row = append(row)
        except Invalid as e:
            print(f"events: refused — {e}", file=sys.stderr)
            return 1
        except OSError as e:
            print(f"events: cannot write — {e}", file=sys.stderr)
            return 2
        print(f'{verdict} {row["key"]}')
        return 0

    if args.cmd == "tail":
        rows = [r for r in _rows(None) if _match(r, args.source, args.kind, args.min_severity)]
        rows = rows[-max(args.n, 0):] if args.n else []
    else:
        needle = args.text.lower()
        rows = [r for r in _rows(args.days) if _match(r, args.source, args.kind, args.min_severity)
                and needle in " ".join(str(r.get(f, "")) for f in FIELDS).lower()]
    for r in rows:
        print(json.dumps(r, ensure_ascii=False, sort_keys=True) if args.json else _line(r))
    return 0


if __name__ == "__main__":
    sys.exit(main())

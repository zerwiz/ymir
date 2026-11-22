#!/usr/bin/env python3
"""nornir-jobs.py — every Nornir job, one row each: its schedule, whose role runs it, when it last ran, how that run
ended, and when it runs next. READ-ONLY: it reads config/cron.yaml, state/cron.log and state/.cron-fired; it writes
nothing (the clock itself is bin/time/nornir-cron-start.sh).

    nornir-jobs.py            a table for a person
    nornir-jobs.py --json     one JSON object (the face Bilskirnir and Valaskjálf read)

Shapes understood (the same as the clock): HH:MM · @hourly · @hourly:MM · @daily · @every:N · Mon|Mon,Fri HH:MM, with an
optional role gate (@heart, @dev, @forge, …) before or after the time. Times are this machine's local time.
Config: YMIR_HOME (the home; default the one home) · NORNIR_CRON_FILE · NORNIR_CRON_LOG (defaults under the home).
"""
from __future__ import annotations

import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HOME = Path(os.environ.get("YMIR_HOME") or (Path.home() / "Documents" / "ymirhome"))
CRON = Path(os.environ.get("NORNIR_CRON_FILE") or HOME / "config" / "cron.yaml")
LOG = Path(os.environ.get("NORNIR_CRON_LOG") or HOME / "state" / "cron.log")
ROOT = Path(os.environ.get("YMIR_ROOT") or Path(__file__).resolve().parents[2])
DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
SHAPE = re.compile(r"^(\d{1,2}:\d{2}|@hourly(:\d{1,2})?|@daily|@every:\d+)$")
DOW = re.compile(r"^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)(,(Mon|Tue|Wed|Thu|Fri|Sat|Sun))*$")


def roles_here() -> list[str]:
    try:
        out = subprocess.run(["bash", str(ROOT / "bin" / "fleet" / "topology.sh"), "--json"], capture_output=True,
                             text=True, timeout=15).stdout
        return json.loads(out).get("roles") or ["dev"]
    except Exception:  # noqa: BLE001
        return ["dev"]


def parse(line: str) -> dict | None:
    toks = line.split()
    gate, days, at = "", [], ""
    while toks:
        t = toks[0]
        if SHAPE.match(t) and not at:
            at = t
        elif DOW.match(t) and not days:
            days = t.split(",")
        elif t.startswith("@") and not SHAPE.match(t) and not gate:
            gate = t[1:]
        else:
            break
        toks.pop(0)
    if not at or not toks:
        return None
    return {"role": gate, "days": days, "at": at, "command": " ".join(toks)}


def next_run(j: dict, now: dt.datetime) -> str:
    at, days = j["at"], j["days"]
    if at.startswith("@every:"):
        n = int(at.split(":")[1]) or 1
        m = (now.minute // n + 1) * n
        t = now.replace(second=0, microsecond=0) + dt.timedelta(minutes=m - now.minute)
        return t.isoformat(timespec="minutes")
    if at.startswith("@hourly"):
        mm = int(at.split(":")[1]) if ":" in at else 0
        t = now.replace(minute=mm, second=0, microsecond=0)
        if t <= now:
            t += dt.timedelta(hours=1)
        return t.isoformat(timespec="minutes")
    hh, mm = (0, 0) if at == "@daily" else map(int, at.split(":"))
    for add in range(0, 8):
        d = now + dt.timedelta(days=add)
        t = d.replace(hour=hh, minute=mm, second=0, microsecond=0)
        if t > now and (not days or DAYS[t.weekday()] in days):
            return t.isoformat(timespec="minutes")
    return ""


def last_runs() -> dict[str, dict]:
    """command → {ran, failed_at, rc, why} from the tail of the clock's log."""
    out: dict[str, dict] = {}
    try:
        lines = LOG.read_text(encoding="utf-8", errors="replace").splitlines()[-20000:]
    except OSError:
        return out
    for ln in lines:
        m = re.match(r"^(\S+Z) cron run: (.+)$", ln)
        if m:
            out.setdefault(m.group(2).strip(), {})["ran"] = m.group(1)
            continue
        m = re.match(r"^(\S+Z) cron FAIL rc=(\d+) (.+?)(?: :: (.*))?$", ln)
        if m:
            r = out.setdefault(m.group(3).strip(), {})
            r.update({"failed_at": m.group(1), "rc": int(m.group(2)), "why": (m.group(4) or "")[:200]})
    return out


def clock_state() -> str:
    try:
        out = subprocess.run(["bash", str(ROOT / "bin" / "time" / "nornir-cron-start.sh"), "--status"], capture_output=True,
                             text=True, timeout=20).stdout.strip().splitlines()
        return out[-1].split(":", 1)[1].strip().split(" ")[0] if out and ":" in out[-1] else "unread"
    except Exception:  # noqa: BLE001
        return "unread"


def main() -> int:
    now = dt.datetime.now().astimezone()
    mine = set(roles_here())
    runs = last_runs()
    jobs = []
    try:
        text = CRON.read_text(encoding="utf-8")
    except OSError:
        text = ""
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].strip() if not raw.strip().startswith("#") else ""
        if not line:
            continue
        j = parse(line)
        if not j:
            jobs.append({"command": line, "invalid": True})
            continue
        r = runs.get(j["command"], {})
        failed = bool(r.get("failed_at")) and r.get("failed_at", "") >= r.get("ran", "")
        j.update({"here": (not j["role"]) or j["role"] in mine, "next": next_run(j, now),
                  "last_ran": r.get("ran", ""), "ok": None if not r else not failed,
                  "rc": r.get("rc") if failed else 0 if r else None, "why": r.get("why", "") if failed else ""})
        jobs.append(j)
    doc = {"machine": os.uname().nodename.split(".")[0], "roles": sorted(mine), "clock": clock_state(),
           "now": now.isoformat(timespec="seconds"), "jobs": jobs,
           "counts": {"jobs": len(jobs), "here": sum(1 for j in jobs if j.get("here")),
                      "failing": sum(1 for j in jobs if j.get("ok") is False),
                      "invalid": sum(1 for j in jobs if j.get("invalid"))}}
    if "--json" in sys.argv:
        print(json.dumps(doc))
        return 0
    print(f"{doc['machine']} · clock {doc['clock']} · roles {','.join(doc['roles'])} · {doc['counts']}")
    for j in jobs:
        if j.get("invalid"):
            print(f"  INVALID  {j['command']}")
            continue
        st = "—" if j["ok"] is None else "ok" if j["ok"] else f"FAIL rc={j['rc']}"
        print(f"  {('@' + j['role']) if j['role'] else '(any)':8} {' '.join(j['days']) + ' ' if j['days'] else ''}{j['at']:10}"
              f" next {j['next'][5:16]:12} last {j['last_ran'][5:16] or '—':12} {st:10} {j['command'][:70]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

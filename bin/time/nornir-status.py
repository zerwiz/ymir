#!/usr/bin/env python3
"""nornir-status.py — judge every Nornir job on the machine that OWNS it (plan 365).

ONE resolver for the Hlidskjalf Cron panel, `ymir nornir` and Eir. A job is never "DOWN" because it is
not this seat's job: its role names an owning seat (fleet registry), the seat's own scheduler log says what
happened (read over the ssh ring, cached 60 s, 4 s timeout), and the verdict is one of ten words:

  RAN       last run ok, within its schedule            ELSEWHERE  not this seat's job, ran fine on its seat
  DUE       not run yet, its time has not come          LATE       its time passed and no run is on record
  FAILED    ran, exit != 0                              DOWN       the owning seat's scheduler is not running
  DARK      the owning seat is unreachable              MOVED      the owner is dark, the heart ran it
  IDLE      ran, nothing to do / not configured         UNREAD     the owning seat's runtime is too old to report (not counted)

The headline counts LATE + FAILED + DOWN + DARK. Every non-green row ends with its next step.
  nornir-status.py [--json] [--no-ssh] [--config F] [--registry F] [--state D]
"""
import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
import time

HEADLINE = {"LATE", "FAILED", "DOWN", "DARK"}
IDLE_RE = re.compile(r"not (armed|configured)|nothing to do|no [A-Z_]{3,}\b", re.I)
DOW = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
AT_RE = re.compile(r"^(@hourly(:\d+)?|@daily|@every:\d+|\d{1,2}:\d{2})$")
DOW_RE = re.compile(r"^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)(,(Mon|Tue|Wed|Thu|Fri|Sat|Sun))*$")


def home():
    return os.environ.get("YMIR_HOME") or os.path.expanduser("~/Documents/ymirhome")


def parse_config(path):
    """The scheduler's own grammar: an @role gate and a day may sit before or after the time."""
    jobs = []
    try:
        lines = open(path).read().splitlines()
    except OSError:
        return jobs
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        toks, gate, at, dow, i = line.split(), "", "", "", 0
        while i < len(toks) and i < 4:
            t = toks[i]
            if AT_RE.match(t):
                at = t
            elif t.startswith("@"):
                gate = t[1:]
            elif DOW_RE.match(t):
                dow = t
            else:
                break
            i += 1
        cmd = " ".join(toks[i:])
        if at and cmd:
            jobs.append({"gate": gate, "at": at, "dow": dow, "cmd": cmd})
    return jobs


def load_registry(path):
    try:
        return json.load(open(path)).get("hosts", {})
    except Exception:
        return {}


def self_identity(hosts):
    me = os.uname().nodename.split(".")[0]
    roles = (hosts.get(me) or {}).get("roles") or []
    env = os.environ.get("BROKK_ROLES")
    if env:
        roles = env.split(",")
    return me, set(roles or ["dev"])


def fetch_seat(name, spec, me, root, state, ssh):
    """One seat's own account of its runs: {reachable, running, now, tz, log, jobs{cmd:(run,fail,rc,note)}}."""
    cache = os.path.join(state, ".nornir-status")
    os.makedirs(cache, exist_ok=True)
    cf = os.path.join(cache, name + ".txt")
    out = None
    if name == me:
        r = subprocess.run(["bash", os.path.join(root, "bin/time/nornir-cron-start.sh"), "--last"], capture_output=True, text=True)
        out = r.stdout
    elif os.path.exists(cf) and time.time() - os.path.getmtime(cf) < 60:
        out = open(cf).read()
    elif ssh:
        tgt = spec.get("tailnet") or spec.get("lan") or name
        dest = f"{spec['user']}@{tgt}" if spec.get("user") else tgt
        remote = ('G=$HOME/ymir-runtime; [ -d "$G/bin" ] || G=$HOME/ymir; '
                  'bash "$G/bin/time/nornir-cron-start.sh" --last')
        try:
            r = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=4", dest, "bash -lc '%s'" % remote],
                               capture_output=True, text=True, timeout=12)
            out = r.stdout if r.returncode == 0 else None
        except Exception:
            out = None
        if out:
            open(cf, "w").write(out)
    seat = {"reachable": bool(out), "old": bool(out) and "#state" not in out, "running": False, "jobs": {}, "now": 0, "tz": 0, "log": ""}
    for ln in (out or "").splitlines():
        f = ln.split("\t")
        if f[0] == "#state":
            seat["running"] = f[1] == "running"
        elif f[0] == "#now":
            seat["now"] = int(f[1])
            z = f[2]
            seat["tz"] = (-1 if z[0] == "-" else 1) * (int(z[1:3]) * 3600 + int(z[3:5]) * 60)
        elif f[0] == "#log":
            seat["log"] = f[1]
        elif len(f) >= 5 and not f[0].startswith("#"):
            seat["jobs"][f[0]] = (f[1], f[2], f[3], f[4])
    return seat


def epoch(iso):
    if not iso:
        return 0
    return int(dt.datetime.strptime(iso, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc).timestamp())


def hhmm(ts, tz):
    return dt.datetime.fromtimestamp(ts + tz, dt.timezone.utc).strftime("%H:%M")


def judge(job, seat, name, hosts):
    """-> (status, detail, next step)"""
    spec = hosts.get(name, {})
    if not seat["reachable"]:
        since = spec.get("dark_since") or "?"
        days = ""
        try:
            days = f" {(dt.date.today() - dt.date.fromisoformat(since)).days} days"
        except Exception:
            pass
        return "DARK", f"{name} dark{days} · ran last {since}", f"bring {name} up, or wait: nothing runs for it until then"
    if seat["old"]:
        return "UNREAD", f"{name} cannot report: update it", f"update {name}: ymir groa (it needs nornir-cron-start.sh --last)"
    if not seat["running"]:
        return "DOWN", f"{name}'s scheduler is not running", f"on {name}: systemctl --user restart nornir  (or bash bin/time/nornir-cron-start.sh)"
    now, tz = seat["now"], seat["tz"]
    run, fail, rc, note = seat["jobs"].get(job["cmd"], ("", "", "", ""))
    run_ts, fail_ts = epoch(run), epoch(fail)
    failed = bool(fail_ts) and fail_ts >= run_ts
    at, nowl = job["at"], dt.datetime.fromtimestamp(now + tz, dt.timezone.utc)
    if job["dow"] and DOW[nowl.weekday()] not in job["dow"].split(","):
        last = f" · last {hhmm(run_ts, tz)}" if run_ts else ""
        return "DUE", f"next {job['dow']} {at} on {name}{last}", ""
    m = re.match(r"^(\d{1,2}):(\d{2})$", at)
    late_next = f"read {seat['log']} on {name}; run it by hand: bash {job['cmd']}"
    if m:
        sched = int(dt.datetime(nowl.year, nowl.month, nowl.day, int(m[1]), int(m[2]), tzinfo=dt.timezone.utc).timestamp()) - tz
        if run_ts < sched - 60:
            if now < sched + 300:
                return "DUE", f"next {at} on {name}", ""
            return "LATE", f"due {at}, no run on {name}", late_next
    else:
        per = 1440 if at == "@daily" else 60 if at.startswith("@hourly") else int(at.split(":")[1])
        if not run_ts or now - run_ts > (2 * per + 5) * 60:
            return "LATE", f"every {per} min, last run {hhmm(run_ts, tz) if run_ts else 'never'} on {name}", late_next
    if failed:
        return ("FAILED", f"failed {hhmm(fail_ts, tz)} on {name} · exit {rc} · log {seat['log']}",
                f"read the FAIL row in {seat['log']} on {name}, fix it, run: bash {job['cmd']}")
    if note and IDLE_RE.search(note):
        return "IDLE", f"ran {hhmm(run_ts, tz)} · {note.strip()[:70]}", ""
    return "RAN", f"ran {hhmm(run_ts, tz)} on {name}", ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--no-ssh", action="store_true")
    ap.add_argument("--config")
    ap.add_argument("--registry")
    ap.add_argument("--state")
    a = ap.parse_args()
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    state = a.state or os.environ.get("BROKK_STATE_OVERRIDE") or os.path.join(
        os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "ymir")
    os.makedirs(state, exist_ok=True)
    cfg = a.config or next((p for p in (os.path.join(home(), "config", "cron.yaml"), os.path.join(root, "config", "cron.yaml"),
                                        os.path.join(root, "config", "cron.yaml.example")) if os.path.exists(p)), "")
    hosts = load_registry(a.registry or os.environ.get("YMIR_FLEET_REGISTRY") or os.path.join(home(), "hodd", "data", "fleet.json"))
    me, my_roles = self_identity(hosts)
    by_role = {}
    for h, v in hosts.items():
        for r in v.get("roles") or []:
            by_role.setdefault(r, []).append(h)
    seats, rows = {}, []

    def seat_for(name):
        if name not in seats:
            seats[name] = fetch_seat(name, hosts.get(name, {}), me, root, state, not a.no_ssh)
        return seats[name]

    for job in parse_config(cfg):
        words = [w for w in job["gate"].split(",") if w]
        owner = me
        if words and not (set(words) & my_roles):
            owner = next((h for w in words for h in by_role.get(w, []) if h != me), None)
        row = dict(job, owner=owner or "?")
        if owner is None:
            if len(hosts) <= 1:  # a fleet of one: the whole road is this machine, and a heart's row has no owner to wait for
                row.update(status="IDLE", detail=f"no {job['gate']} seat in this fleet — not armed here", next="")
            else:
                row.update(status="DARK", detail=f"no seat in the fleet registry holds role {job['gate']}",
                           next="add the host to fleet.json or drop the row")
            rows.append(row)
            continue
        st, detail, nxt = judge(job, seat_for(owner), owner, hosts)
        # The fallback seat is the owner's `fallback` in the fleet registry; a dark forge falls back to the heart.
        fb = (hosts.get(owner) or {}).get("fallback") or ("heart" if words == ["forge"] else "")
        heart = None
        if fb:
            heart = me if fb in my_roles or fb == me else next(iter(by_role.get(fb, [fb] if fb in hosts else [])), None)
        if st == "DARK" and heart:
            hs, hd, hn = judge(job, seat_for(heart), heart, hosts)
            if hs in ("RAN", "IDLE"):
                st, detail, nxt = "MOVED", f"{owner} dark → ran on {heart} {hd.split(' ')[1]} ✓", ""
            else:
                detail = f"{detail}; fallback on {heart}: {hd}"
                nxt = nxt if hs == "DUE" else hn
        elif st == "RAN" and owner != me:
            st, detail = "ELSEWHERE", f"runs on {job['gate']} ({owner}) · {detail.split(' on ')[0]} ✓"
        row.update(status=st, detail=detail, next=nxt)
        rows.append(row)
    counts = {}
    for r in rows:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    needs = sum(1 for r in rows if r["status"] in HEADLINE)
    res = {"self": me, "config": cfg, "needs": needs, "counts": counts, "jobs": rows,
           "seats": {n: {"reachable": s["reachable"], "running": s["running"], "log": s["log"]} for n, s in seats.items()}}
    if a.json:
        print(json.dumps(res))
        return 1 if needs else 0
    print(f"nornir[{len(rows)}]{{status,owner,at,job,detail,next}}:")
    for r in rows:
        print("  " + ",".join(json.dumps(str(x), ensure_ascii=False) for x in (r["status"], r["owner"], r["at"], r["cmd"], r["detail"], r["next"])))
    print("needs: %d   (%s)" % (needs, ", ".join(f"{k} {v}" for k, v in counts.items())))
    return 1 if needs else 0


if __name__ == "__main__":
    sys.exit(main())

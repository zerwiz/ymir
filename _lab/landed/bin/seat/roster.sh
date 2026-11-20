#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$HERE/../.." && pwd)"
export ROSTER_MODE="${1:-list}"
export ROSTER_ROOT="$ROOT"
exec python3 - <<'PY'
import json, os, subprocess, sys
from collections import Counter
root = os.environ["ROSTER_ROOT"]
mode = os.environ.get("ROSTER_MODE", "list")
herdr_fixture = os.environ.get("ROSTER_HERDR_FIXTURE", "")
ps_fixture = os.environ.get("ROSTER_PS_FIXTURE", "")
state_file = os.environ.get("ROSTER_STATE_FILE", root + "/state/roster.json")
arm_cycle_file = os.environ.get("ROSTER_ARM_CYCLE_FILE", root + "/state/.arm-last-cycle")

def herdr_list():
    if herdr_fixture:
        try:
            return json.load(open(herdr_fixture))
        except Exception as e:
            return {"error": str(e), "agents": []}
    try:
        out = subprocess.run(["herdr", "agent", "list"], capture_output=True, text=True, timeout=10)
        return json.loads(out.stdout)
    except Exception as e:
        return {"error": str(e), "agents": []}

def ps_list():
    if ps_fixture:
        return open(ps_fixture).read()
    try:
        out = subprocess.run(["ps", "-eo", "pid,comm,args"], capture_output=True, text=True, timeout=10)
        return out.stdout
    except Exception as e:
        return ""

data = herdr_list()
agents = (data.get("result") or {}).get("agents") or data.get("agents") or []
seats = []
for a in agents:
    seats.append({
        "pane": a.get("pane_id") or a.get("pane") or "?",
        "role": a.get("name") or a.get("agent") or "agent",
        "state": a.get("agent_status") or a.get("state") or "unknown",
        "worktree": a.get("cwd") or a.get("foreground_cwd") or "",
        "branch": "",
        "errand": a.get("name") or "",
        "age": "",
    })
for s in seats:
    wt = s["worktree"]
    if wt and os.path.isdir(wt):
        try:
            b = subprocess.run(["git", "-C", wt, "rev-parse", "--abbrev-ref", "HEAD"],
                               capture_output=True, text=True, timeout=5)
            s["branch"] = b.stdout.strip()
        except Exception:
            s["branch"] = ""

ps_text = ps_list()
agent_procs = []
for line in ps_text.splitlines():
    parts = line.split(None, 2)
    if len(parts) < 3:
        continue
    pid, comm, args = parts[0], parts[1], parts[2]
    low = (comm + " " + args).lower()
    if any(tok in low for tok in ["pi", "opencode", "hermes", "agent-run"]):
        if "roster" in args:
            continue
        agent_procs.append((pid, comm, args))

findings = []
for s in seats:
    if not s["errand"] and s["state"] not in ("done", "idle", "terminal"):
        findings.append(f"seat {s['pane']} has no errand and no terminal status")
live_roles = [s["role"] for s in seats if s["state"] in ("working", "idle", "unknown")]
dup = [r for r, c in Counter(live_roles).items() if c > 1]
for r in dup:
    findings.append(f"role {r} holds two live seats")
if len(agent_procs) > len(seats):
    for pid, comm, args in agent_procs[len(seats):]:
        findings.append(f"unowned agent process: pid {pid} {comm}")
if os.path.exists(state_file) and os.path.exists(arm_cycle_file):
    if os.path.getmtime(state_file) < os.path.getmtime(arm_cycle_file):
        findings.append("state/roster.json older than arm's last cycle")
if len(seats) != len(agent_procs) and len(agent_procs) > 0:
    findings.append(f"herdr/ps disagreement: herdr={len(seats)} ps={len(agent_procs)}")

if mode == "--json":
    print(json.dumps({"seats": seats, "counts": {
        "total": len(seats), "primary": 1, "reviewer": 1,
        "building": sum(1 for s in seats if s["state"] == "working"),
        "idle": sum(1 for s in seats if s["state"] in ("idle", "done")),
        "stale": 0,
    }, "findings": findings}, indent=2))
    sys.exit(1 if findings else 0)

if mode == "line":
    building = sum(1 for s in seats if s["state"] == "working")
    idle = sum(1 for s in seats if s["state"] in ("idle", "done"))
    stale = 0
    print(f"roster: {len(seats)} seats · 1 primary · 1 reviewer · {building} building · {idle} idle · {stale} stale")
    sys.exit(0)

if mode == "--check":
    for f in findings:
        print("FINDING:", f)
    print(f"herdr: {len(seats)} seats")
    print(f"ps: {len(agent_procs)} agent processes")
    sys.exit(1 if findings else 0)

for s in seats:
    print(f"{s['pane']}\t{s['role']}\t{s['state']}\t{s['worktree']}\t{s['branch']}\t{s['errand']}\t{s['age']}")
for f in findings:
    print("FINDING:", f)
sys.exit(0)
PY

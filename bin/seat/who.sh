#!/usr/bin/env bash
# who.sh — WHO IS WHERE: every agent in a pane, its project, its errand, and who holds the lock.
#
# WHY THIS EXISTS (the Allfather, 2026-11-08: *"you need to know whos ansering and who youre sending
# to"*). Twice today a line was addressed to "all panes" — once it reached the Allfather instead of the
# lock holder, and once a keeper was seated whose figure misbehaved and there was no way to say whom.
# A message with no identity behind it and no identity in front of it is a shout in a crowded hall.
#
# It reads three sources and joins them, so nothing is guessed:
#   herdr agent list            → pane, agent name, harness, cwd
#   the cwd                      → the project (`<repo>/.yggdrasil/<id>` gives the ERRAND's id)
#   the lock record + herdr pane process-info → which pane hosts the session that holds the lock
#
#   who.sh                # the register: pane · agent · project · errand · role
#   who.sh --names        # one resolvable target name per line (what a sender may address)
#   who.sh <name>         # resolve ONE name to its pane, refusing on none or many
#   who.sh --me           # this seat's own pane and identity
#
# Exit: 0 ok · 1 a name that does not resolve to exactly one pane · 2 usage.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 - "$ROOT" "$@" <<'PY'
import json, os, subprocess, sys

root = sys.argv[1]
args = sys.argv[2:]

def herdr(*a, timeout=25):
    try:
        out = subprocess.run(["herdr", *a], capture_output=True, text=True, timeout=timeout).stdout
        return json.loads(out or "{}")
    except Exception:
        return {}

def agents():
    d = herdr("agent", "list")
    return (d.get("result") or {}).get("agents") or []

def lock_owner():
    p = os.path.join(os.environ.get("HOME", ""), ".local/state/ymir/brokk.lock")
    try:
        return "".join(c for c in open(p).read() if c.isdigit())
    except Exception:
        return ""

def project_of(cwd):
    """The project a pane is standing in: an errand's worktree names the ERRAND, and the registry names
    the project — so a line can say where it came from instead of 'some pane'."""
    if not cwd:
        return ("", "")
    parts = cwd.rstrip("/").split("/")
    if ".yggdrasil" in parts:
        i = parts.index(".yggdrasil")
        errand = parts[i + 1] if i + 1 < len(parts) else ""
        return (os.path.basename("/".join(parts[:i])), errand)
    return (os.path.basename(cwd), "")

def my_pane():
    d = herdr("pane", "current")
    r = d.get("result") or d
    return (r.get("pane") or {}).get("pane_id") or r.get("pane_id") or ""

rows = []
owner = lock_owner()
for a in agents():
    pane = a.get("pane_id") or ""
    cwd = a.get("cwd") or ""
    name = a.get("name") or ""
    project, errand = project_of(cwd)
    holds = ""
    if pane:
        info = herdr("pane", "process-info", "--pane", pane, timeout=15)
        blob = json.dumps(info)
        if owner and ('"pid": %s' % owner in blob or '"pid":%s' % owner in blob):
            holds = "lock-holder"
    rows.append({"pane": pane, "name": name, "kind": a.get("kind") or a.get("harness") or "",
                 "project": project, "errand": errand, "cwd": cwd, "holds": holds,
                 "state": a.get("state") or a.get("status") or "?"})

me = my_pane()
for r in rows:
    if r["pane"] == me:
        r["holds"] = (r["holds"] + ",me").strip(",")

def label(r):
    bits = [r["name"] or r["pane"]]
    if r["project"]:
        bits.append(r["project"])
    if r["errand"]:
        bits.append("errand:" + r["errand"])
    if r["holds"]:
        bits.append(r["holds"])
    return " · ".join(bits)

if not args:
    print(f'panes[{len(rows)}]{{pane,name,project,errand,kind,holds,state}}:')
    for r in rows:
        print(f'  "{r["pane"]}","{r["name"]}","{r["project"]}","{r["errand"]}","{r["kind"]}","{r["holds"]}","{r["state"]}"')
    sys.exit(0)

if args[0] == "--names":
    for r in rows:
        if r["name"]:
            print(r["name"])
    sys.exit(0)

if args[0] == "--me":
    mine = [r for r in rows if r["pane"] == me]
    if not mine:
        print(f'me[1]{{pane,state}}:\n  "{me or "unknown"}","not listed as an agent"')
        sys.exit(0)
    r = mine[0]
    print(f'me[1]{{pane,label,project,errand,holds}}:\n  "{r["pane"]}","{label(r)}","{r["project"]}","{r["errand"]}","{r["holds"]}"')
    sys.exit(0)

# resolve ONE name (or a pane id) to exactly one pane
want = args[0]
hits = [r for r in rows if want in (r["name"], r["pane"])]
if not hits:
    hits = [r for r in rows if r["name"].startswith(want)]
if len(hits) == 1:
    print(f'target[1]{{name,pane,label}}:\n  "{hits[0]["name"] or hits[0]["pane"]}","{hits[0]["pane"]}","{label(hits[0])}"')
    sys.exit(0)
if not hits:
    sys.stderr.write(f'error: no agent answers to {want!r}\nhelp: bin/seat/who.sh --names\n')
    sys.exit(1)
sys.stderr.write(f'error: {want!r} names {len(hits)} panes — say which\n')
for r in hits:
    sys.stderr.write(f'  {r["pane"]}  {label(r)}\n')
sys.exit(1)
PY

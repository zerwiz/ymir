#!/usr/bin/env bash
# hlidskjalf-agents.sh — WHO IS ACTUALLY STANDING, and what they are doing.
#
# The control plane showed the ROSTER: the twenty profiles that *could* run.
# A roster is a leaflet; the panes are the truth. This reads the live pane list
# (herdr) and emits the sessions that exist right now, so the Fleet gate shows a
# fleet rather than a painting of one — every opencode and pi session, with its
# kind, its state, its pane and where it works.
#
#   bin/hlidskjalf-agents.sh            # JSON (what /api/agents serves)
#   bin/hlidskjalf-agents.sh --toon     # TOON (for a human at a terminal)
#
# State comes from the pane's own reported status. Nothing here infers liveness
# from a process list or from prose: if herdr does not say an agent is there, it
# is not on the board.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HERDR="${HERDR_BIN_PATH:-herdr}"
MODE="json"
[ "${1:-}" = "--toon" ] && MODE="toon"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

command -v "$HERDR" >/dev/null 2>&1 || { [ "$MODE" = json ] && printf '[]\n' || printf 'agents[0]{name}:\n'; exit 0; }

raw="$("$HERDR" pane list 2>/dev/null)"

MODE="$MODE" RAW="$raw" python3 - <<'PY'
import json, os, sys

mode = os.environ.get("MODE", "json")
raw = os.environ.get("RAW", "")

def live():
    try:
        d = json.loads(raw)
    except Exception:
        return []
    panes = (d.get("result") or {}).get("panes") or d.get("panes") or []
    out = []
    for p in panes:
        # an agent pane is one herdr names an agent for; a bare shell is not on
        # the fleet board (it is a terminal, not a worker)
        agent = p.get("agent") or ""
        if not agent and p.get("agent_status") in (None, "", "unknown"):
            continue
        title = (p.get("terminal_title_stripped") or p.get("terminal_title") or "").strip()
        cwd = p.get("foreground_cwd") or p.get("cwd") or ""
        state = p.get("agent_status") or "unknown"
        # a task reads as "OC | <task>" in the pane title; keep it, it is the
        # agent's own word for what it is doing
        task = title.split("|", 1)[1].strip() if "|" in title else ""
        # The UI's AgentCard shape, so the board RENDERS rather than carrying
        # fields it does not know. Live facts come from the pane; the identity
        # fields it cannot know (role, domain, model) stay honest and empty
        # rather than invented - a card may show "-", never a false name.
        status = {"working": "nominal", "idle": "nominal"}.get(state, "degraded")
        out.append({
            "id": p.get("pane_id", ""),
            "name": title.split("|")[0].strip() or agent or p.get("pane_id", ""),
            "role": agent or "agent",
            "realm": "work",
            "domain": "ymirlabs",
            "status": status,
            "capabilities": [],
            "skills": [],
            "interface": {
                "protocol": "a2a/1.0",
                "endpoint": "local://%s" % p.get("pane_id", ""),
                "signed": False,
            },
            "model": "",
            "uptime": 0,
            "tasksDone": 0,
            # live facts the board can show beyond the card contract
            "live": {
                "kind": agent or "unknown",
                "state": state,
                "pane": p.get("pane_id", ""),
                "workspace": p.get("workspace_id", ""),
                "cwd": cwd,
                "task": task,
            },
        })
    return out

rows = live()

if mode == "json":
    print(json.dumps(rows))
    raise SystemExit

print("agents[%d]{name,kind,state,pane,cwd,task}:" % len(rows))
for r in rows:
    q = lambda s: '"%s"' % str(s).replace('"', '\\"')
    print("  %s,%s,%s,%s,%s,%s" % (q(r["name"]), q(r["kind"]), q(r["state"]), q(r["pane"]), q(r["cwd"]), q(r["task"])))
if not rows:
    print("agents: 0 live sessions — nothing is standing")
PY

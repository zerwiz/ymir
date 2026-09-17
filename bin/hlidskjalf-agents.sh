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

ROSTER_DIR = os.environ.get("ROSTER_DIR", ".agents/agents")

def panes():
    """The STANDING seats: a herdr pane an agent runs in. A pane is the WHERE."""
    try:
        d = json.loads(raw)
    except Exception:
        return []
    pl = (d.get("result") or {}).get("panes") or d.get("panes") or []
    out = []
    for p in pl:
        agent = p.get("agent") or ""
        if not agent and p.get("agent_status") in (None, "", "unknown"):
            continue
        title = (p.get("terminal_title_stripped") or p.get("terminal_title") or "").strip()
        out.append({
            "id": p.get("pane_id", ""),
            "name": title.split("|")[0].strip() or agent or p.get("pane_id", ""),
            "harness": agent or "agent",
            "state": p.get("agent_status") or "unknown",
            "title": title,
            "cwd": p.get("foreground_cwd") or p.get("cwd") or "",
            "workspace": p.get("workspace_id", ""),
            "task": title.split("|", 1)[1].strip() if "|" in title else "",
            "matched": False,
        })
    return out


def roster():
    """The AGENTS, from the canonical roster (.agents/agents/*.md).

    A pane is the where; this is the WHO. Emitting panes alone is why the Fleet
    showed thirteen OpenCode terminals and not one of the smiths who might be
    standing in them. The roster is canonical (RULES/02); a harness seat is not an
    agent, and an agent is not its seat.
    """
    try:
        files = sorted(f for f in os.listdir(ROSTER_DIR) if f.endswith(".md"))
    except Exception:
        return []
    out = []
    for f in files:
        stem = f[:-3]
        parts = stem.split("-")
        model = mode = domain = ""
        try:
            with open(os.path.join(ROSTER_DIR, f)) as fh:
                txt = fh.read(6000)
            if txt.startswith("---"):
                for line in txt.split("---", 2)[1].splitlines():
                    if line.startswith("model:") and not model:
                        model = line.split(":", 1)[1].strip()
                    if line.startswith("mode:") and not mode:
                        mode = line.split(":", 1)[1].strip()
                    if line.startswith("domain:") and not domain:
                        domain = line.split(":", 1)[1].strip()
        except Exception:
            pass
        out.append({
            "stem": stem,
            "figure": parts[0],
            "craft": parts[1] if len(parts) > 1 else "agent",
            "model": model,
            "mode": mode,
            "domain": domain,
        })
    return out


ps = panes()
rs = roster()
rows = []

def card(name, role, model, state, domain="ymirlabs", pane=None, task="", where=""):
    status = {"working": "nominal", "idle": "nominal", "unseated": "seated"}.get(state, "degraded")
    return {
        "id": pane["id"] if pane else "roster:" + name,
        "name": name,
        "role": role,
        "realm": "work",
        "domain": domain,
        "status": status,
        "capabilities": [],
        "skills": [],
        "interface": {
            "protocol": "a2a/1.0",
            "endpoint": ("local://%s" % pane["id"]) if pane else "",
            "signed": False,
        },
        "model": model or (pane["harness"] if pane else ""),
        "uptime": 0,
        "tasksDone": 0,
        "kind": role,
        "state": state,
        "pane": pane["id"] if pane else "",
        "cwd": (pane["cwd"] if pane else where),
        "task": task,
        "live": ({
            "kind": pane["harness"], "state": state, "pane": pane["id"],
            "workspace": pane["workspace"], "cwd": pane["cwd"], "task": pane["task"],
        } if pane else None),
    }

# THE AGENTS FIRST — every smith on the roster, seated or not. An unseated agent is
# still an agent; hiding it made the board look like a rack of terminals.
for a in rs:
    hit = None
    for p in ps:
        hay = ("%s %s %s" % (p["name"], p["harness"], p["title"])).lower()
        if a["figure"] and a["figure"] in hay:
            p["matched"] = True
            hit = p
            break
    rows.append(card(a["figure"], a["craft"], a["model"],
                     hit["state"] if hit else "unseated",
                     domain=a["domain"] or "ymirlabs",
                     pane=hit, task=hit["task"] if hit else ""))

# Harness seats that answer to no one on the roster: kept visible, named honestly.
for p in ps:
    if not p["matched"]:
        rows.append(card(p["name"], p["harness"], p["harness"], p["state"], pane=p,
                         task=p["task"]))

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

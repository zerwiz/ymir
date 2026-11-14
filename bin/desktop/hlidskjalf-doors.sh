#!/usr/bin/env bash
# hlidskjalf-doors.sh — WHERE EVERY APP AND EVERY AGENT CAN BE INSPECTED.
#
# Plan 275 item 19, at the Allfather's word: *"we need to have devtools attached to all
# agents harnesses"*. Two kinds of door, and both are listed here so the Fleet page can
# name them rather than describe them:
#
#   an APP's door    its DevTools (CDP): http://127.0.0.1:<fixed port>/json/version
#                    The ports come from bin/desktop/app-lib.sh app_devtools_port — the
#                    one table — and are probed here, never assumed. "up" means the port
#                    answered CDP this second.
#   an AGENT's door  its herdr pane: `herdr agent read <pane>` prints what the agent is
#                    doing without steering it. An agent has a door only when a pane
#                    really holds it (the same rule as its card: NOMINAL means alive).
#
#   bin/desktop/hlidskjalf-doors.sh            # JSON (what /api/doors serves)
#   bin/desktop/hlidskjalf-doors.sh --toon     # TOON for a human at a terminal
#
# It reads; it never attaches. Nothing here starts, stops or restarts an app: a door that
# is down is reported down, and the repair is a person's (or boot-stopwatch's) call.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="json"
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --toon) MODE="toon" ;;
esac

# The ONE table of ports, and the ONE connector for agents.
# shellcheck source=/dev/null
. "$SCRIPT_DIR/app-lib.sh"

APP_SURFACES="hlidskjalf smidja odrerir sessrumnir bilskirnir rodd"

# The agent list is the connector's own answer — a second reader here would drift from
# the cards the Fleet page shows beside it.
AGENTS_JSON=""
if [ -x "$SCRIPT_DIR/hlidskjalf-agents.sh" ]; then
  AGENTS_JSON="$(timeout 12 "$SCRIPT_DIR/hlidskjalf-agents.sh" 2>/dev/null || true)"
fi

MODE="$MODE" PORTS="$(for _s in $APP_SURFACES; do printf '%s=%s\n' "$_s" "$(app_devtools_port "$_s")"; done)" \
AGENTS_JSON="$AGENTS_JSON" \
python3 - <<'PY'
import json, os, sys, urllib.request

mode = os.environ.get("MODE", "json")
agents_raw = os.environ.get("AGENTS_JSON", "")

# The ports come from the same table the launchers read (app-lib.sh); this only names them.
PORTS = {}
for line in os.environ.get("PORTS", "").splitlines():
    if "=" in line:
        s, p = line.split("=", 1)
        if p.strip().isdigit():
            PORTS[s.strip()] = int(p.strip())
surfaces = list(PORTS)

def probe(port, timeout=0.35):
    """Answer CDP on loopback — the only proof a door is open."""
    try:
        with urllib.request.urlopen("http://127.0.0.1:%d/json/version" % port, timeout=timeout) as r:
            body = json.loads(r.read() or b"{}")
            return True, str(body.get("Browser") or body.get("browser") or "cdp")
    except Exception as e:
        # The reason is summarised, not dumped: "no CDP here" says it in a card row.
        reason = str(e)
        if "Connection refused" in reason or "Errno 111" in reason:
            return False, "no CDP on that port"
        return False, reason[:60]

apps = []
for s in surfaces:
    port = PORTS.get(s, 0)
    up, note = probe(port) if port else (False, "no port in the table")
    apps.append({
        "surface": s,
        "port": port,
        "url": ("http://127.0.0.1:%d/json/version" % port) if port else "",
        "up": up,
        "note": note,
    })

agents = []
try:
    rows = json.loads(agents_raw) if agents_raw.strip() else []
except ValueError:
    rows = []
for r in rows:
    if not r.get("alive"):
        continue
    pane = r.get("pane") or ""
    agents.append({
        "pane": pane,
        "name": r.get("name") or "",
        "label": r.get("paneLabel") or "",
        "harness": r.get("harness") or "",
        "errand": r.get("errand") or "",
        # The door is a COMMAND a person or an agent runs, not a URL: herdr owns the
        # pane, and `agent read` is how you look in without steering the agent.
        "door": ("herdr agent read %s" % pane) if pane else "",
    })

payload = {
    "apps": apps,
    "agents": agents,
    "apps_up": sum(1 for a in apps if a["up"]),
    "agents_seated": len(agents),
}
if mode == "json":
    print(json.dumps(payload))
    raise SystemExit(0)

q = lambda v: '"%s"' % str(v if v is not None else "").replace('"', '\\"')
print("doors[1]{apps_up,apps,agents_seated}:")
print("  %d,%d,%d" % (payload["apps_up"], len(apps), payload["agents_seated"]))
print("app_doors[%d]{surface,port,up,url}:" % len(apps))
for a in apps:
    print("  %s,%s,%s,%s" % (q(a["surface"]), a["port"], "yes" if a["up"] else "no", q(a["url"])))
print("agent_doors[%d]{name,pane,harness,door}:" % len(agents))
for a in agents:
    print("  %s,%s,%s,%s" % (q(a["name"]), q(a["pane"]), q(a["harness"]), q(a["door"])))
if not agents:
    print("agent_doors: 0 — no pane holds an agent")
PY

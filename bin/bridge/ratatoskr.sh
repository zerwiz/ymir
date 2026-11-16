#!/usr/bin/env bash
# ratatoskr.sh — Ymir's front door to the A2A engine (`a2abridge`).
#
#   bin/bridge/ratatoskr.sh status            # engine + directory health + served agents
#   bin/bridge/ratatoskr.sh who [--local]      # THE DIRECTORY: every agent on every fleet machine, and who holds the arm
#   bin/bridge/ratatoskr.sh send <target> "…"  # ONE QUEUE: write a task, then wake the target (step 4)
#   bin/bridge/ratatoskr.sh reply <id> "…"     # answer a task: the file moves to done/ and the answer is its record
#   bin/bridge/ratatoskr.sh claim <id>         # take a task off the shelf (the claim is the rename)
#   bin/bridge/ratatoskr.sh inbox [--for T]    # what is waiting, on all three shelves
#   bin/bridge/ratatoskr.sh doctor            # a2abridge's full health-check
#   bin/bridge/ratatoskr.sh directory start|stop|status   # the local discovery daemon
#   bin/bridge/ratatoskr.sh service ...       # systemd-user / launchd service management
#   bin/bridge/ratatoskr.sh cert ...          # ed25519 cert+key for cross-machine federation
#   bin/bridge/ratatoskr.sh version
#
# The engine is the authority; this is a Ymir-shaped, fail-safe wrapper.
set -u

VERSION="1.0.0"
A2AB="${A2ABRIDGE_BIN:-$HOME/.a2abridge/bin/a2abridge}"
DIR_URL="${A2A_DIRECTORY:-http://127.0.0.1:7777}"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-status}"; shift || true

# who — the DIRECTORY (plan 303 §12.3 step 2). herdr is the directory: it lists the panes
# that exist NOW on this machine, and each fleet machine is asked over its own road. No
# announce step, so a stale peer cannot be listed — and a machine that does not answer is
# a row that says so, never a row quietly dropped. It is answered BEFORE the engine check,
# because the directory does not need a2abridge to be present: reading herdr and the hermes
# store is enough.
if [ "$ACTION" = who ]; then
  exec python3 "$(dirname "$0")/ratatoskr-who.py" "$@"
fi

# send | reply | claim | inbox | show | count — ONE queue for the whole house (plan 303 §12.3
# step 3). A task is a Markdown file; the claim is a RENAME, so two receivers cannot both
# win one; a reply moves it to done/ and the file is the record of the whole exchange.
case "$ACTION" in
  send|reply|claim|inbox|show|count)
    exec python3 "$(dirname "$0")/ratatoskr-queue.py" "$ACTION" "$@" ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }

# agents — discover the FLEET's live A2A peers. A peer service binds where peers can
# reach it on a STABLE port (A2A_PORT, default 8391); this probes every ONLINE
# tailnet peer on that port and prints the cards that answer. This is the missing
# half of Ratatoskr: the local directory lists only this seat; this lists the fleet.
cmd_agents() {
  local port="${A2A_PORT:-8391}" hosts rows="" n=0 h url card name
  if have tailscale; then
    hosts="$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys
try:
 d=json.load(sys.stdin)
 for v in (d.get("Peer") or {}).values():
  if v.get("Online"): print((v.get("DNSName") or "").rstrip("."))
except Exception: pass' 2>/dev/null)"
  fi
  hosts="$(printf '%s\n%s\n' "$(hostname)" "$hosts" | grep -v '^$' | sort -u)"
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    url="http://$h:$port"
    card="$(curl -s --max-time 4 "$url/.well-known/agent-card.json" 2>/dev/null)"
    case "$card" in *'"name"'*)
      name="$(printf '%s' "$card" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("name","?"))
except Exception: print("?")' 2>/dev/null)"
      rows="$rows$(printf '  "%s","%s","%s"\n' "$h" "$url" "$name")"
      n=$((n + 1)) ;;
    esac
  done <<< "$hosts"
  printf 'a2a-agents[%s]{seat,url,name}:\n' "$n"
  if [ "$n" = 0 ]; then
    printf '  "none","-:%s","no live A2A peer found"\n' "$port"
  else
    printf '%s' "$rows"
  fi
}
[ -x "$A2AB" ] || A2AB="$(command -v a2abridge 2>/dev/null || true)"
[ -n "$A2AB" ] && [ -x "$A2AB" ] || { printf 'error: a2abridge not found\nhelp: %s\n' "$A2AB" >&2; exit 1; }

case "$ACTION" in
  status)
    printf 'ratatoskr[1]{engine,version}:\n  "%s","%s"\n' "$A2AB" "$("$A2AB" version 2>/dev/null | head -1)"
    printf 'directory[1]{url,state,agents}:\n'
    body="$(curl -s --max-time 4 "$DIR_URL/" 2>/dev/null)"
    if [ -n "$body" ]; then
      printf '  "%s","up","%s"\n' "$DIR_URL" "$(printf '%s' "$body" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(",".join(a.get("name","") for a in d.get("served_agents",[])) or "none")
except Exception: print("?")' 2>/dev/null)"
    else
      printf '  "%s","down","none"\n' "$DIR_URL"
    fi ;;
  doctor) exec "$A2AB" doctor ;;
  directory)
    sub="${1:-status}"
    case "$sub" in
      start) exec "$A2AB" directory & ;;
      stop|status) exec "$A2AB" service "$sub" ;;
      *) printf 'error: directory start|stop|status\n' >&2; exit 2 ;;
    esac ;;
  service|cert|worker|install|uninstall|update|completion) exec "$A2AB" "$ACTION" "$@" ;;
  agents) cmd_agents ;;
  *) printf 'error: unknown action %s\nhelp: bin/bridge/ratatoskr.sh [status|who|agents|doctor|directory|service|cert|version]\n' "$ACTION" >&2; exit 2 ;;
esac

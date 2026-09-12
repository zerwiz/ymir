#!/usr/bin/env bash
# ratatoskr.sh — Ymir's front door to the A2A engine (`a2abridge`).
#
#   bin/ratatoskr.sh status            # engine + directory health + served agents
#   bin/ratatoskr.sh doctor            # a2abridge's full health-check
#   bin/ratatoskr.sh directory start|stop|status   # the local discovery daemon
#   bin/ratatoskr.sh service ...       # systemd-user / launchd service management
#   bin/ratatoskr.sh cert ...          # ed25519 cert+key for cross-machine federation
#   bin/ratatoskr.sh version
#
# The engine is the authority; this is a Ymir-shaped, fail-safe wrapper.
set -u

VERSION="1.0.0"
A2AB="${A2ABRIDGE_BIN:-$HOME/.a2abridge/bin/a2abridge}"
DIR_URL="${A2A_DIRECTORY:-http://127.0.0.1:7777}"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-status}"; shift || true

have() { command -v "$1" >/dev/null 2>&1; }
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
  *) printf 'error: unknown action %s\nhelp: bin/ratatoskr.sh [status|doctor|directory|service|cert|version]\n' "$ACTION" >&2; exit 2 ;;
esac

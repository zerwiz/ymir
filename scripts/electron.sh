#!/usr/bin/env bash
# electron.sh — the Ymir desktop shell (Hlidskjalf + Smiðja) in Electron.
# Raises the web stack, then opens the native window. Galdr-style TOON.
#
# Usage:
#   electron.sh [start] [--no-install]   # launch the desktop app
#   electron.sh stop
#   electron.sh status
#   electron.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$ROOT/apps/hlidskjalf"
PID_FILE="$ROOT/state/electron.pid"
LOG_FILE="$ROOT/state/electron.log"
NO_INSTALL=0

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-start}"; shift || true
while [ $# -gt 0 ]; do case "$1" in --no-install) NO_INSTALL=1; shift ;; *) shift ;; esac; done

running() { [ -r "$PID_FILE" ] && kill -0 "$(tr -d '[:space:]' <"$PID_FILE")" 2>/dev/null; }

case "$ACTION" in
  status)
    if running; then printf 'electron[1]{state,pid}:\n  "up",%s\n' "$(tr -d '[:space:]' <"$PID_FILE")"; else printf 'electron[1]{state,pid}:\n  "down",0\n'; fi
    exit 0 ;;
  stop)
    if running; then pid=$(tr -d '[:space:]' <"$PID_FILE"); kill "$pid" 2>/dev/null || true; rm -f "$PID_FILE"; printf 'electron: stopped pid=%s\n' "$pid"; else printf 'electron: already stopped\n'; fi
    exit 0 ;;
  start) ;;
  *) printf 'error: unknown action %s\nhelp: electron.sh [start|stop|status]\n' "$ACTION" >&2; exit 2 ;;
esac

command -v npm >/dev/null 2>&1 || { printf 'error: npm not found\nhelp: install node/npm to run the desktop shell\n' >&2; exit 1; }
mkdir -p "$ROOT/state"

if [ ! -x "$APP/node_modules/.bin/electron" ]; then
  if [ "$NO_INSTALL" = 1 ]; then
    printf 'error: electron not installed in %s\nhelp: (cd apps/hlidskjalf && npm install)\n' "$APP" >&2; exit 1
  fi
  printf 'electron: installing dependencies (first run)…\n' >&2
  ( cd "$APP" && npm install ) >/dev/null 2>&1 || { printf 'error: npm install failed — see apps/hlidskjalf\n' >&2; exit 1; }
fi

nohup "$APP/node_modules/.bin/electron" "$APP" >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
sleep 2
if running; then printf 'electron[1]{state,pid,url}:\n  "up",%s,"http://127.0.0.1:3888/"\n' "$(cat "$PID_FILE")"; else printf 'error: electron failed to start; see %s\n' "${LOG_FILE#"$ROOT"/}" >&2; exit 1; fi

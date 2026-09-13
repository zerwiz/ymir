#!/usr/bin/env bash
# sessrumnir.sh — launch the Sessrúmnir desktop GUI (the seat-hall).
# Ensures deps + build are present (bin/sessrumnir-ensure.sh), then raises the
# Electron window via the app's own launcher. Galdr-style TOON.
#
# Usage:
#   sessrumnir.sh [start] [path]     # launch (deps installed on first run)
#   sessrumnir.sh start ~/my-project # launch with a workspace
#   sessrumnir.sh status
#   sessrumnir.sh stop
#   sessrumnir.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$ROOT/apps/sessrumnir"
PID_FILE="$ROOT/state/sessrumnir.pid"
LOG_FILE="$ROOT/state/sessrumnir.log"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-start}"; shift || true
WORKSPACE="${1-}"

# The launcher spawns Electron as its child; track the real Electron by its
# command line — the Sessrúmnir user-data-dir is a unique, stable identity.
view_pids() {
  pgrep -f "electron/dist/electron.*sessrumnir" 2>/dev/null || true
}
is_running() { [ -n "$(view_pids)" ]; }

case "$ACTION" in
  status)
    if is_running; then
      p="$(view_pids | head -1)"
      printf 'sessrumnir[1]{state,pid}:\n  "up",%s\n' "$p"
    else
      printf 'sessrumnir[1]{state,pid}:\n  "down",0\n'
    fi
    exit 0 ;;
  stop)
    pids="$(view_pids)"
    if [ -n "$pids" ]; then
      printf '%s\n' "$pids" | while IFS= read -r p; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done
      printf 'sessrumnir: stopped pid(s)=%s\n' "$(printf '%s' "$pids" | tr '\n' ',' | sed 's/,$//')"
    fi
    rm -f "$PID_FILE"
    printf 'sessrumnir: stopped\n'
    exit 0 ;;
  start) ;;
  *) printf 'error: unknown action %s\nhelp: bin/sessrumnir.sh [start|status|stop]\n' "$ACTION" >&2; exit 2 ;;
esac

if is_running; then
  printf 'sessrumnir[1]{state,pid}:\n  "already up",%s\n' "$(view_pids | head -1)"
  exit 0
fi

"$SCRIPT_DIR/sessrumnir-ensure.sh" ensure --install >/dev/null 2>&1 || {
  printf 'error: Sessrúmnir is not ready — run bin/sessrumnir-ensure.sh install\n' >&2
  exit 1
}

mkdir -p "$ROOT/state"
args=()
[ -n "$WORKSPACE" ] && args+=("$WORKSPACE")

nohup node "$APP/bin/sessrumnir.js" "${args[@]}" >"$LOG_FILE" 2>&1 < /dev/null &
echo $! >"$PID_FILE"

i=0
for i in $(seq 1 30); do [ -n "$(view_pids)" ] && break; sleep 0.5; done

if is_running; then
  printf 'sessrumnir[1]{state,pid}:\n  "up",%s\n' "$(view_pids | head -1)"
else
  printf 'error: Sessrúmnir failed to start; see %s\n' "${LOG_FILE#"$ROOT"/}" >&2
  exit 1
fi
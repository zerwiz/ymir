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
# Where an app lives: apps/<surface> in a clone, node_modules/@zerwiz/<pkg> in an
# npm install — both shapes, one resolver (bin/app-lib.sh).
if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
  _ya="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yac in "$_ya/app-lib.sh" "$(dirname "$_ya")/bin/app-lib.sh"; do
    [ -r "$_yac" ] && { . "$_yac"; YMIR_APP_LIB_LOADED=1; break; }
  done
  unset _ya _yac
fi
app_dir sessrumnir APP_SESSRUMNIR || APP_SESSRUMNIR=""


# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
APP="$APP_SESSRUMNIR"
PID_FILE="$YMIR_STATE_DIR/sessrumnir.pid"
LOG_FILE="$YMIR_STATE_DIR/sessrumnir.log"

# npm gates install scripts, so the Electron runtime a seat needs is often absent
# after a global install — the window then cannot open and says nothing useful.
# Mend it before refusing (the same lesson as scripts/electron.sh).
repair_runtime() {
  local dir="$1"
  [ -f "$dir/node_modules/electron/path.txt" ] && return 0
  command -v npm >/dev/null 2>&1 || return 1
  echo "Sessrúmnir — its Electron runtime is absent; fetching it (this is the gated postinstall)…" >&2
  ( cd "$dir" && npm rebuild electron >/dev/null 2>&1 ) && [ -f "$dir/node_modules/electron/path.txt" ]
}

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-start}"; shift || true
WORKSPACE="${1-}"

# The launcher spawns Electron as its child; track the real Electron by its
# command line — the Sessrúmnir user-data-dir is a unique, stable identity.
view_pids() {
  pgrep -f "electron/dist/electron.*sessrumnir" 2>/dev/null || true
}
is_running() { [ -n "$(view_pids)" ]; }

# Raise the running window. The desktop-placement rule may have opened it on its
# own numbered desktop (desktop-place.sh), so a launch from elsewhere would
# otherwise show nothing — the focus dispatch also switches to where it sits.
# Omarchy configures Hyprland in Lua, so the dispatch is a Lua expression (the
# classic `focuswindow class:...` form does not parse).
focus_window() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl dispatch "hl.dsp.focus({window=\"class:^sessrumnir\$\"})" >/dev/null 2>&1 || true
}

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
  focus_window
  printf 'sessrumnir[1]{state,pid}:\n  "already up",%s\n' "$(view_pids | head -1)"
  exit 0
fi

"$SCRIPT_DIR/sessrumnir-ensure.sh" ensure --install >/dev/null 2>&1 || {
  printf 'error: Sessrúmnir is not ready — run bin/sessrumnir-ensure.sh install\n' >&2
  exit 1
}

mkdir -p "$YMIR_STATE_DIR"
args=()
[ -n "$WORKSPACE" ] && args+=("$WORKSPACE")

nohup node "$APP/bin/sessrumnir.js" "${args[@]}" >"$LOG_FILE" 2>&1 < /dev/null &
echo $! >"$PID_FILE"

i=0
for i in $(seq 1 30); do [ -n "$(view_pids)" ] && break; sleep 0.5; done

if is_running; then
  focus_window
  printf 'sessrumnir[1]{state,pid}:\n  "up",%s\n' "$(view_pids | head -1)"
else
  printf 'error: Sessrúmnir failed to start; see %s\n' "${LOG_FILE#"$ROOT"/}" >&2
  exit 1
fi
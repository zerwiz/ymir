#!/usr/bin/env bash
# sessrumnir.sh — launch the Sessrúmnir desktop GUI (the seat-hall).
# Ensures deps + build are present (bin/desktop/sessrumnir-ensure.sh), then raises the
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
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
# Where an app lives: apps/<surface> in a clone, node_modules/@zerwiz/<pkg> in an
# npm install — both shapes, one resolver (bin/desktop/app-lib.sh).
if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
  _ya="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yac in "$_ya/app-lib.sh" "$(CDPATH='' cd "$_ya" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)/bin/desktop/app-lib.sh"; do
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
  for _yc in "$_yr/hoard-lib.sh" "$_yr/../vault/hoard-lib.sh" "$_yr/../../vault/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
APP="$APP_SESSRUMNIR"
# Resolve-or-die (the 2026-09-23 SIGTRAP guard): never launch electron with
# an empty or concatenated app path.
[ -n "$APP" ] && [ -d "$APP" ] || { printf 'error: cannot resolve the sessrumnir app\nhelp: (cd apps/sessrumnir && npm ci)\n' >&2; exit 1; }
PID_FILE="$YMIR_STATE_DIR/sessrumnir.pid"
LOG_FILE="$YMIR_STATE_DIR/sessrumnir.log"

# npm gates install scripts, so the Electron runtime a seat needs is often absent
# after a global install — the window then cannot open and says nothing useful.
# Mend it before refusing (the same lesson as scripts/electron.sh). Resolver-aware
# (P1): the binary is found by electron_bin, the mend installs at the workspace
# root for a member (P3), and fetches land in the resolved dir.

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-start}"; shift || true
WORKSPACE="${1-}"

# The launcher spawns Electron as its child; track the real Electron by its
# command line — the Sessrúmnir user-data-dir is a unique, stable identity.
# Every process carrying the Sessrúmnir identity: the main process AND its
# Electron helpers (gpu/utility/renderer). The helpers outlive a dead main —
# they are re-parented to the user systemd — so this list is for REAPING only.
all_pids() {
  pgrep -f "electron/dist/electron.*sessrumnir" 2>/dev/null || true
}
# The MAIN process only. An Electron helper always carries --type=; the main
# never does. Matching the helpers here is what made `status` say "up" and
# `start` say "already up" while the window was gone (2026-10-31).
view_pids() {
  local p
  for p in $(all_pids); do
    tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null | grep -q -- "--type=" && continue
    printf '%s\n' "$p"
  done
}
is_running() { [ -n "$(view_pids)" ]; }

# Raise the running window. The desktop-placement rule may have opened it on its
# own numbered desktop (desktop-place.sh), so a launch from elsewhere would
# otherwise show nothing — the focus dispatch also switches to where it sits.
# Omarchy configures Hyprland in Lua, so the dispatch is a Lua expression (the
# classic `focuswindow class:...` form does not parse).
focus_window() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl dispatch "hl.dsp.focus({window=\"class:^ymir-sessrumnir\$\"})" >/dev/null 2>&1 || true
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
    pids="$(all_pids)"
    if [ -n "$pids" ]; then
      printf '%s\n' "$pids" | while IFS= read -r p; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done
      printf 'sessrumnir: stopped pid(s)=%s\n' "$(printf '%s' "$pids" | tr '\n' ',' | sed 's/,$//')"
    fi
    rm -f "$PID_FILE"
    printf 'sessrumnir: stopped\n'
    exit 0 ;;
  start) ;;
  *) printf 'error: unknown action %s\nhelp: bin/desktop/sessrumnir.sh [start|status|stop]\n' "$ACTION" >&2; exit 2 ;;
esac

if is_running; then
  focus_window
  printf 'sessrumnir[1]{state,pid}:\n  "already up",%s\n' "$(view_pids | head -1)"
  exit 0
fi

# A dead main leaves its helpers running as orphans of the user systemd. They
# still carry the identity string, so reaping them before the launch is the
# difference between a window and "started but nothing appeared".
stale="$(all_pids)"
if [ -n "$stale" ]; then
  printf '%s\n' "$stale" | while IFS= read -r p; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done
  sleep 1
fi

"$SCRIPT_DIR/../desktop/sessrumnir-ensure.sh" ensure --install >/dev/null 2>&1 || {
  printf 'error: Sessrúmnir is not ready — run bin/desktop/sessrumnir-ensure.sh install\n' >&2
  exit 1
}

mkdir -p "$YMIR_STATE_DIR"
args=()
[ -n "$WORKSPACE" ] && args+=("$WORKSPACE")

# P7 graphics policy (2026-09-24): on a fragile hybrid (a shared-memory iGPU
# beside a dGPU) Electron's GPU process dies for want of a fence and the browser
# makes SIGTRAP suicide once the process is judged unusable — sessrumnir crashed
# exactly this way twice on this box. Resolve the ONE machine-wide answer the
# same way scripts/electron.sh does (bin/host/graphics-lib.sh, never a hardcode) and
# export the EFFECTIVE override for the app's node launcher, which appends the
# --disable-gpu flags. 1/true/yes and 0/false/no remain the human override.
if [ -z "${YMIR_GRAPHICS_LIB_LOADED:-}" ]; then
  for _gc in "$SCRIPT_DIR/../host/graphics-lib.sh" "$ROOT/bin/host/graphics-lib.sh"; do
    [ -r "$_gc" ] && { . "$_gc"; YMIR_GRAPHICS_LIB_LOADED=1; break; }
  done
  unset _gc
fi
case "${YMIR_DESKTOP_DISABLE_GPU:-auto}" in
  1|true|yes) YMIR_DESKTOP_DISABLE_GPU=1 ;;
  0|false|no) YMIR_DESKTOP_DISABLE_GPU=0 ;;
  *)
    if [ "${YMIR_GRAPHICS_LIB_LOADED:-0}" = 1 ]; then
      _gp="$(graphics_policy 2>/dev/null || true)"
      [ -n "$_gp" ] || _gp=gpu
    else
      _gp=gpu
    fi
    [ "$_gp" = software ] && YMIR_DESKTOP_DISABLE_GPU=1 || YMIR_DESKTOP_DISABLE_GPU=0
    unset _gp ;;
esac
export YMIR_DESKTOP_DISABLE_GPU

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
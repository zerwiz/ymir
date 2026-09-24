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
repair_runtime() {
  local dir="$1" root bin edir installd
  if [ -z "${YMIR_ELECTRON_LIB_LOADED:-}" ] && [ -r "$(dirname "$0")/electron-lib.sh" ]; then
    . "$(dirname "$0")/electron-lib.sh"; YMIR_ELECTRON_LIB_LOADED=1
  fi
  root="$(electron_root "$dir")"
  bin="$(electron_bin "$dir" "$root" sessrumnir 2>/dev/null || true)"
  [ -n "$bin" ] && [ -x "$bin" ] && return 0
  command -v npm >/dev/null 2>&1 || return 1
  echo "Sessrúmnir — its Electron runtime is absent; fetching it (this is the gated postinstall)…" >&2
  # tier 1 — the deps may be ungated entirely; tier 2 — approve + rebuild
  if electron_is_workspace_member "$dir" "$root"; then installd="$root"; else installd="$dir"; fi
  ( cd "$installd" && { npm install --include=dev >/dev/null 2>&1; npm install-scripts approve electron >/dev/null 2>&1 || true; npm rebuild electron >/dev/null 2>&1; } )
  # tier 3 — the postinstall's own downloader, then the PROVEN zip road
  edir="$(electron_pkg_dir "$dir" "$root" sessrumnir 2>/dev/null || true)"
  [ -n "$edir" ] && [ -f "$edir/install.js" ] && ( cd "$edir" && node install.js >/dev/null 2>&1 ) || true
  command -v fetch_electron_zip >/dev/null 2>&1 && fetch_electron_zip "$dir" "$root" sessrumnir || true
  bin="$(electron_bin "$dir" "$root" sessrumnir 2>/dev/null || true)"
  [ -n "$bin" ] && [ -x "$bin" ]
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

# P7 graphics policy (2026-09-24): on a fragile hybrid (a shared-memory iGPU
# beside a dGPU) Electron's GPU process dies for want of a fence and the browser
# makes SIGTRAP suicide once the process is judged unusable — sessrumnir crashed
# exactly this way twice on this box. Resolve the ONE machine-wide answer the
# same way scripts/electron.sh does (bin/graphics-lib.sh, never a hardcode) and
# export the EFFECTIVE override for the app's node launcher, which appends the
# --disable-gpu flags. 1/true/yes and 0/false/no remain the human override.
if [ -z "${YMIR_GRAPHICS_LIB_LOADED:-}" ]; then
  for _gc in "$SCRIPT_DIR/graphics-lib.sh" "$ROOT/bin/graphics-lib.sh"; do
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
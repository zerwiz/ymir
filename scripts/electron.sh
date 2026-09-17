#!/usr/bin/env bash
# electron.sh — the Ymir desktop shell (Hlidskjalf + Smiðja) in Electron.
# Raises the web stack, then opens the native window(s). Galdr-style TOON.
#
# Hlidskjalf and Smiðja are separate desktop apps (own app-id, .desktop, icon)
# so they never stack in the taskbar. `--both` starts both processes.
#
# Usage:
#   electron.sh [start] [--no-install]        # launch the desktop app
#   electron.sh start --view hlidskjalf|smidja
#   electron.sh start --both                  # both apps, separate processes
#   electron.sh stop
#   electron.sh status
#   electron.sh --version
set -u

# --- portability shim: bin/ymir-platform.sh --------------------------------
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  _ymir_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  for _ymir_c in "$(dirname "$_ymir_dir")/bin/ymir-platform.sh" "$_ymir_dir/bin/ymir-platform.sh"; do
    [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_dir _ymir_c
fi

VERSION="1.1.0"
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
app_dir hlidskjalf APP_HLIDSKJALF || APP_HLIDSKJALF=""
app_dir odrerir APP_ODRERIR || APP_ODRERIR=""
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
APP="$APP_HLIDSKJALF"
Odrerir_app="$APP_ODRERIR"
NO_INSTALL=0
VIEW="${YMIR_DESKTOP_VIEW:-hlidskjalf}"
VIEWS=(hlidskjalf smidja odrerir)

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-start}"; shift || true
while [ $# -gt 0 ]; do case "$1" in
  --no-install) NO_INSTALL=1; shift ;;
  --view) VIEW=${2-hlidskjalf}; shift 2 ;;
  --both) VIEW=both; shift ;;
  *) shift ;;
esac; done

pid_file() { case "$1" in smidja) printf '%s/state/electron-smidja.pid' "$ROOT" ;; odrerir) printf '%s/state/electron-odrerir.pid' "$ROOT" ;; *) printf '%s/state/electron.pid' "$ROOT" ;; esac; }
log_file() { case "$1" in smidja) printf '%s/state/electron-smidja.log' "$ROOT" ;; odrerir) printf '%s/state/electron-odrerir.log' "$ROOT" ;; *) printf '%s/state/electron.log' "$ROOT" ;; esac; }

# The `.bin/electron` shim is a node script that SPAWNS the real Electron, so its
# pid (`$!`) is not the app. Track Electron by its own command line instead — the
# per-view user-data-dir is a unique, stable identity — exactly as the Nornir
# scheduler identifies itself. Without this, a stale/reused pid makes is_running
# false while Electron is alive, and a second app launches on top of the first.
view_mark() { case "$1" in smidja) printf '%s' 'ymir-smidja' ;; odrerir) printf '%s' 'ymir-odrerir' ;; *) printf '%s' 'ymir-hlidskjalf' ;; esac; }
view_pids() {  # all live Electron pids for a view
  local mark; mark="$(view_mark "$1")"
  pgrep -f "electron/dist/electron.*--user-data-dir=.*${mark}" 2>/dev/null || true
}
# An integrated GPU backs its graphics memory with system RAM: a small VRAM
# carve-out plus a large shared aperture (GTT). When a local model is served
# on that same iGPU it can hold several GiB of GTT, and the amdgpu driver then
# fails command submissions for the desktop's GPU process — which Electron
# turns into a NULL dereference, killing the GPU process while the window
# survives. These are dashboards, not 3D, so software rendering costs nothing.
IGPU_VRAM_SMALL_MIB="${YMIR_IGPU_VRAM_SMALL_MIB:-2048}"
igpu_vram_small() {
  local d total
  for d in /sys/class/drm/card*/device; do
    [ -r "$d/mem_info_vram_total" ] || continue
    total=$(( $(cat "$d/mem_info_vram_total" 2>/dev/null || echo 0) / 1048576 ))
    [ "$total" -gt 0 ] && [ "$total" -lt "$IGPU_VRAM_SMALL_MIB" ] && return 0
  done
  return 1
}

real_electron() { printf '%s' "$APP/node_modules/electron/dist/electron"; }
is_running() {
  local pids; pids="$(view_pids "$1")"
  [ -n "$pids" ]
}
pid_of() {
  # Prefer the recorded pid when it is one of the live Electron pids; else the first.
  local rec pids; pids="$(view_pids "$1")"
  [ -n "$pids" ] || { printf '0'; return; }
  rec="$(tr -d '[:space:]' <"$(pid_file "$1")" 2>/dev/null || true)"
  if [ -n "$rec" ] && printf '%s\n' "$pids" | grep -qx "$rec"; then printf '%s' "$rec"; return; fi
  printf '%s' "$(printf '%s\n' "$pids" | head -1)"
}

stop_view() {  # stop ONE view's pids - and only that view's
  local v="$1" pids
  pids="$(view_pids "$v")"
  if [ -z "$pids" ]; then
    printf 'electron: %s already stopped\n' "$v"
    rm -f "$(pid_file "$v")"
    return 0
  fi
  local list; list="$(printf '%s' "$pids" | tr '\n' ',')"
  printf '%s\n' "$pids" | xargs -r kill 2>/dev/null || true
  sleep 0.5
  local left; left="$(view_pids "$v")"
  [ -z "$left" ] || printf '%s\n' "$left" | xargs -r kill -KILL 2>/dev/null || true
  rm -f "$(pid_file "$v")"
  printf 'electron: stopped %s pid(s)=%s\n' "$v" "${list%,}"
}

case "$ACTION" in
  status)
    printf 'electron[%s]{view,state,pid}:\n' "${#VIEWS[@]}"
    for v in "${VIEWS[@]}"; do
      if is_running "$v"; then printf '  "%s","up",%s\n' "$v" "$(pid_of "$v")"; else printf '  "%s","down",0\n' "$v"; fi
    done
    exit 0 ;;
  stop)
    # ONLY the view asked for. Walking every view here is why `stop --view odrerir`
    # used to take the smithy's window down with it.
    if [ "$VIEW" = both ]; then
      for v in "${VIEWS[@]}"; do stop_view "$v"; done
    else
      stop_view "$VIEW"
    fi
    printf 'electron: stopped\n'
    exit 0 ;;
  start|hlidskjalf|smidja|odrerir) [ "$ACTION" = smidja ] && VIEW=smidja; [ "$ACTION" = odrerir ] && VIEW=odrerir ;;
  *) printf 'error: unknown action %s\nhelp: electron.sh [start|stop|status]\n' "$ACTION" >&2; exit 2 ;;
esac

command -v npm >/dev/null 2>&1 || { printf 'error: npm not found\nhelp: install node/npm to run the desktop shell\n' >&2; exit 1; }
mkdir -p "$YMIR_STATE_DIR"

if [ ! -x "$APP/node_modules/.bin/electron" ]; then
  if [ "$NO_INSTALL" = 1 ]; then
    printf 'error: electron not installed in %s\nhelp: (cd apps/hlidskjalf && npm install)\n' "$APP" >&2; exit 1
  fi
  printf 'electron: installing dependencies (first run)…\n' >&2
  ( cd "$APP" && npm install ) >/dev/null 2>&1 || { printf 'error: npm install failed — see apps/hlidskjalf\n' >&2; exit 1; }
fi

# npm 11+ gates postinstall scripts (allowScripts), so Electron's binary is
# often never downloaded even though the package installed. Heal that here:
# run the package's own postinstall, and if it still yields no binary, extract
# from the already-cached zip and write path.txt (what the postinstall does).
ensure_electron_binary() {
  local bin="$APP/node_modules/electron/dist/electron"
  [ -x "$bin" ] && return 0
  [ -d "$APP/node_modules/electron" ] || return 0   # nothing installed yet
  if [ -f "$APP/node_modules/electron/install.js" ]; then
    ( cd "$APP" && node node_modules/electron/install.js ) >/dev/null 2>&1 || true
  fi
  [ -x "$bin" ] && return 0
  # Fall back to the download cache, which the postinstall populated.
  local zip
  zip="$(ls "$HOME"/.cache/electron/*/electron-v*-linux-*.zip 2>/dev/null | head -1)"
  if [ -n "$zip" ] && command -v unzip >/dev/null 2>&1; then
    mkdir -p "$APP/node_modules/electron/dist"
    unzip -q -o "$zip" -d "$APP/node_modules/electron/dist" >/dev/null 2>&1 && \
      printf 'electron' >"$APP/node_modules/electron/path.txt"
  fi
  [ -x "$bin" ] && return 0
  return 1
}

if ! ensure_electron_binary; then
  printf 'error: the Electron binary is missing (the package installed but its postinstall was blocked)\nhelp: cd apps/hlidskjalf && node node_modules/electron/install.js\nhelp: if npm blocks install scripts, run: npm install --foreground-scripts\n' >&2
  exit 1
fi

app_dir() { case "$1" in odrerir) printf '%s' "$Odrerir_app" ;; *) printf '%s' "$APP" ;; esac; }
view_host() { case "$1" in smidja) printf '%s' 'http://127.0.0.1:8437/' ;; odrerir) printf '%s' 'http://127.0.0.1:4322/' ;; *) printf '%s' 'http://127.0.0.1:3888/' ;; esac; }

service_up() { curl -s -o /dev/null --max-time 3 "$1" 2>/dev/null; }
wait_for_service() {
  local u="$1" i
  for i in $(seq 1 120); do service_up "$u" && return 0; sleep 0.5; done
  return 1
}
# Does the compositor hold a window of this class at all? A process with no window
# cannot be focused, and focusing nothing is exactly the silence a click must not get.
window_present() {
  command -v hyprctl >/dev/null 2>&1 || return 0   # no compositor to ask: assume yes
  hyprctl clients 2>/dev/null | grep -qi "$1"
}

start_one() {
  local v="$1" f l
  f="$(pid_file "$v")"; l="$(log_file "$v")"
  # THE SYSTEM FIRST. A shell whose backing service is down draws an empty window,
  # and a window that never mapped cannot be focused. Clicking an icon must raise
  # THE SYSTEM, so the service is converged before the window is judged.
  local host; host="$(view_host "$v")"
  if ! service_up "$host"; then
    printf 'electron: %s has no service at %s — raising the system\n' "$v" "$host" >&2
    ( nohup bash "$ROOT/scripts/start.sh" >/dev/null 2>&1 </dev/null & )
    if ! wait_for_service "$host"; then
      printf 'electron: %s still does not answer at %s — see $YMIR_STATE_DIR/\n' "$v" "$host" >&2
    fi
    # A process that lived through the outage is windowless; it must be reborn.
    if is_running "$v"; then stop_view "$v"; fi
  fi
  if is_running "$v"; then
    # A bound key must RAISE the app, never report that it is already up. The
    # window lives on its own numbered desktop by design, so "nothing happens"
    # is exactly what a click must not do. focuswindow also switches desktops.
    local cls state=already-up
    cls="$(view_mark "$v")"   # the window class, from the one place that defines it
    if command -v hyprctl >/dev/null 2>&1; then
      # Omarchy configures Hyprland in Lua, so `hyprctl dispatch` evaluates the
      # remainder as a Lua expression — the classic `focuswindow class:...`
      # string form is a syntax error there. This is the working idiom.
      hyprctl dispatch "hl.dsp.focus({window=\"class:^${cls}\$\"})" >/dev/null 2>&1 && state=raised
    fi
    # A process whose window is gone cannot be focused — reborn, not silent.
    if [ "$state" = already-up ] && ! window_present "$cls"; then
      printf 'electron: %s is running without a window — restarting it\n' "$v" >&2
      stop_view "$v"
    else
      printf 'electron[1]{view,state,pid}:\n  "%s","%s",%s\n' "$v" "$state" "$(pid_of "$v")"
      return 0
    fi
  fi
  # Launch the REAL Electron binary, not the .bin node shim, so the recorded pid
  # is the app itself (the shim spawns and would leave a stale/incorrect pid).
  local bin; bin="$(real_electron)"
  local -a extra=()
  # GPU safety — see igpu_vram_small() above for why this exists.
  #   YMIR_DESKTOP_DISABLE_GPU=1  force software rendering
  #   YMIR_DESKTOP_DISABLE_GPU=0  force the GPU path
  #   unset (auto)                decide from the device's VRAM carve-out
  case "${YMIR_DESKTOP_DISABLE_GPU:-auto}" in
    1|true|yes) extra+=(--disable-gpu --disable-gpu-compositing) ;;
    0|false|no) : ;;
    *)
      if [ "$(ymir_os 2>/dev/null)" = linux ] && igpu_vram_small; then
        extra+=(--disable-gpu --disable-gpu-compositing)
      fi ;;
  esac
  nohup env YMIR_DESKTOP_VIEW="$v" "$(real_electron)" "$(app_dir "$v")" \
    --user-data-dir="$HOME/.config/$(view_mark "$v")" \
    "${extra[@]}" >"$l" 2>&1 < /dev/null &
  echo $! >"$f"
  # Wait briefly for the real process to appear, so a following call sees it.
  local i
  for i in $(seq 1 20); do [ -n "$(view_pids "$v")" ] && break; sleep 0.5; done
}

if [ "$VIEW" = both ]; then
  start_one hlidskjalf
  start_one smidja
  start_one odrerir
  sleep 2
  for v in "${VIEWS[@]}"; do
    if is_running "$v"; then printf 'electron[1]{view,state,pid,url}:\n  "%s","up",%s,"%s"\n' "$v" "$(pid_of "$v")" "$(view_host "$v")"; else printf 'error: electron %s failed to start; see %s\n' "$v" "${log_file "$v"#"$ROOT"/}" >&2; exit 1; fi
  done
else
  start_one "$VIEW"
  sleep 2
  if is_running "$VIEW"; then printf 'electron[1]{view,state,pid,url}:\n  "%s","up",%s,"%s"\n' "$VIEW" "$(pid_of "$VIEW")" "$(view_host "$VIEW")"; else printf 'error: electron failed to start; see %s\n' "${log_file "$VIEW"#"$ROOT"/}" >&2; exit 1; fi
fi

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
# A fresh package install has no state/ yet — the door must stand it up.
mkdir -p "$ROOT/state"
# Where an app lives: apps/<surface> in a clone, node_modules/@zerwiz/<pkg> in an
# npm install — both shapes, one resolver (bin/app-lib.sh).
if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
  _ya="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yac in "$_ya/app-lib.sh" "$(dirname "$_ya")/bin/app-lib.sh"; do
    [ -r "$_yac" ] && { . "$_yac"; YMIR_APP_LIB_LOADED=1; break; }
  done
  unset _ya _yac
fi
# The runtime resolver (P1) and the graphics policy (P7) live in bin/ — every
# launcher, every doctor, and the installer read the SAME answer, never an
# app-local hardcode (2026-09-24).
if [ -z "${YMIR_ELECTRON_LIB_LOADED:-}" ] && [ -r "$ROOT/bin/electron-lib.sh" ]; then
  . "$ROOT/bin/electron-lib.sh"; YMIR_ELECTRON_LIB_LOADED=1
fi
if [ -z "${YMIR_GRAPHICS_LIB_LOADED:-}" ] && [ -r "$ROOT/bin/graphics-lib.sh" ]; then
  . "$ROOT/bin/graphics-lib.sh"; YMIR_GRAPHICS_LIB_LOADED=1
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
# Resolve-or-die: an empty app path launched electron against garbage (the
# 2026-09-23 SIGTRAP — a stray ' s/' reached the argv and the app aborted).
[ -n "$APP" ] || { printf 'error: cannot resolve the app (%s)\nhelp: (cd apps/%s && npm ci) or reinstall the package\n' "${VIEW:-hlidskjalf}" "${VIEW:-hlidskjalf}" >&2; exit 1; }
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
# P7 (2026-09-24): the old test read mem_info_vram_total only — i915 NEVER
# exposes that file — so on this Intel + discrete hybrid the guard never fired
# and the GPU process died for want of a fence (SIGABRT, no OOM). The fragile
# case is now classified from the DRM devices themselves: a shared-memory
# integrated device beside a discrete one (bin/graphics-lib.sh). GTT is read
# where amdgpu exposes it; the small-carve-out read remains only as the
# fallback when the lib is not present.
igpu_vram_small() {
  local d total
  if [ -z "${YMIR_GRAPHICS_LIB_LOADED:-}" ] && [ -r "$ROOT/bin/graphics-lib.sh" ]; then
    . "$ROOT/bin/graphics-lib.sh"; YMIR_GRAPHICS_LIB_LOADED=1
  fi
  if [ "${YMIR_GRAPHICS_LIB_LOADED:-0}" = 1 ] && graphics_hybrid_fragile; then return 0; fi
  for d in /sys/class/drm/card*/device; do
    [ -r "$d/mem_info_vram_total" ] || continue
    total=$(( $(cat "$d/mem_info_vram_total" 2>/dev/null || echo 0) / 1048576 ))
    [ "$total" -gt 0 ] && [ "$total" -lt "$IGPU_VRAM_SMALL_MIB" ] && return 0
  done
  return 1
}

# P1 (2026-09-24): the ONE resolver. The launcher execs whatever electron_bin
# finds for THIS surface's app dir — app-local, workspace-hoisted, or the
# sibling package — never a path npm will not make. real_electron takes the
# view because smidja/odrerir live in different app dirs than hlidskjalf.
real_electron() {  # <surface|view>
  local s="${1:-$VIEW}"
  [ "$s" = both ] && s=hlidskjalf
  electron_bin "$(app_dir "$s")" "$ROOT" "$(app_pkg "$s")"
}
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

# P3 (2026-09-24): npm workspaces HOIST a member app's deps to the root — an
# install inside the member reconciles the tree and REMOVES the local
# node_modules the launcher was about to use. Install at the workspace root
# when the app is a member; app-local only for a standalone app.
electron_install_root() {  # <app-dir> → the dir whose package.json owns the deps
  if electron_is_workspace_member "$1" "$ROOT"; then printf '%s' "$ROOT"; else printf '%s' "$1"; fi
}

if ! electron_bin "$(app_dir hlidskjalf)" "$ROOT" hlidskjalf >/dev/null 2>&1 \
   && [ ! -x "$ROOT/node_modules/.bin/electron" ] && [ ! -x "$APP/node_modules/.bin/electron" ]; then
  if [ "$NO_INSTALL" = 1 ]; then
    printf 'error: electron not installed in %s\nhelp: (cd %s && npm install)\n' "$(app_dir hlidskjalf)" "$(electron_install_root "$APP")" >&2; exit 1
  fi
  printf 'electron: installing dependencies (first run)…\n' >&2
  local _installd; _installd="$(electron_install_root "$APP")"
  ( cd "$_installd" && npm install ) >/dev/null 2>&1 || { printf 'error: npm install failed — see %s\n' "$_installd" >&2; exit 1; }
fi

# npm 11+ gates postinstall scripts (allowScripts), so Electron's binary is
# often never downloaded even though the package installed. Heal that here:
# run the package's own postinstall, and if it still yields no binary, extract
# from the already-cached zip and write path.txt (what the postinstall does).
# P2 (2026-09-24): absence is NEVER success. The old guard returned 0 when the
# runtime was absent — the mend was skipped and the launcher exec'd a path
# that did not exist, and every check said healthy. Only a resolver-verified,
# answering executable is success. Do not reintroduce a bare `return 0` on the
# absent branch; see .agents/tests/electron-lib.test.sh.
ensure_electron_binary() {
  local bin v
  v="$VIEW"; [ "$v" = both ] && v=hlidskjalf
  bin="$(electron_bin "$(app_dir "$v")" "$ROOT" "$(app_pkg "$v")")" || return 1
  [ -n "$bin" ] && [ -x "$bin" ] || return 1
  "$bin" --version >/dev/null 2>&1
}

# npm gates install scripts by default (11.16+ warns, 12 refuses), and Electron's
# postinstall is what downloads the runtime — so a fresh install can build the web
# app perfectly and still have no window. Before refusing, do the mending a user
# would otherwise be told to do by hand: approve the script and rebuild.
repair_electron() {  # <app-dir>
  local dir="$1"
  command -v npm >/dev/null 2>&1 || return 1
  # npm gates the rebuild as well as the postinstall: approve first, or the mend
  # silently changes nothing and the window still never opens.
  ( cd "$dir" && { npm install-scripts approve electron >/dev/null 2>&1 || true; npm rebuild electron >/dev/null 2>&1; } )
}
if ! ensure_electron_binary; then
  # npm-independent: fetch the release as the postinstall would (bin/electron-lib.sh)
  local mend_pkg; mend_pkg="$(app_pkg hlidskjalf)"
  # tier 1 — the deps themselves may be ungated (npm's policy skips dev-deps):
  # the npm package's apps arrive without node_modules at all
  ( cd "$(electron_install_root "$APP")" && npm install --include=dev >/dev/null 2>&1 ) || true
  command -v electron_fetch_runtime >/dev/null 2>&1 && electron_fetch_runtime "$APP" "$ROOT" "$mend_pkg" || true
  # Try the mending ourselves before telling the user to do it by hand: npm's
  # gating is the cause, and the cure is one command we can run.
  echo "the Electron runtime is partial — mending it (npm rebuild electron)…" >&2
  repair_electron "$(electron_install_root "$APP")" >/dev/null 2>&1 || true
  # tier 3 — the postinstall's own downloader, then the PROVEN zip road
  local _edir; _edir="$(electron_pkg_dir "$APP" "$ROOT" "$mend_pkg" 2>/dev/null || true)"
  [ -n "$_edir" ] && [ -f "$_edir/install.js" ] && ( cd "$_edir" && node install.js >/dev/null 2>&1 ) || true
  command -v fetch_electron_zip >/dev/null 2>&1 && fetch_electron_zip "$APP" "$ROOT" "$mend_pkg" || true
  ensure_electron_binary || {
    printf 'error: the Electron runtime could not be mended\nhelp: cd <the app> && npm install-scripts approve electron && npm rebuild electron\nhelp: or run the web surfaces only: ymir install --no-desktop\n' >&2
    exit 1
  }
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
  local bin; bin="$(real_electron "$v")"
  [ -n "$bin" ] && [ -x "$bin" ] || { printf 'error: no Electron runtime for %s — run the installer or npm install at the workspace root\n' "$v" >&2; exit 1; }
  local -a extra=()
  # GPU safety — see igpu_vram_small() above for why this exists. The effective
  # policy is ONE decision (bin/graphics-lib.sh), recorded by the sense snapshots;
  # YMIR_DESKTOP_DISABLE_GPU remains the human override (P7, 2026-09-24).
  #   1            force software rendering
  #   0            force the GPU path
  #   unset (auto) decide from the machine's DRM classification
  case "${YMIR_DESKTOP_DISABLE_GPU:-auto}" in
    1|true|yes) extra+=(--disable-gpu --disable-gpu-compositing) ;;
    0|false|no) : ;;
    *)
      if [ "$(ymir_os 2>/dev/null)" = linux ]; then
        local gp; gp="$(graphics_policy 2>/dev/null || true)"
        [ -n "$gp" ] || { igpu_vram_small && gp=software || gp=gpu; }
        [ "$gp" = software ] && extra+=(--disable-gpu --disable-gpu-compositing)
      fi ;;
  esac
  nohup env YMIR_DESKTOP_VIEW="$v" "$(real_electron "$v")" "$(app_dir "$v")" \
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
    if is_running "$v"; then printf 'electron[1]{view,state,pid,url}:\n  "%s","up",%s,"%s"\n' "$v" "$(pid_of "$v")" "$(view_host "$v")"; else printf 'error: electron %s failed to start; see %s\n' "$v" "$(log_file "$v")" >&2; exit 1; fi
  done
else
  start_one "$VIEW"
  sleep 2
  if is_running "$VIEW"; then printf 'electron[1]{view,state,pid,url}:\n  "%s","up",%s,"%s"\n' "$VIEW" "$(pid_of "$VIEW")" "$(view_host "$VIEW")"; else printf 'error: electron failed to start; see %s\n' "$(log_file "$VIEW")" >&2; exit 1; fi
fi

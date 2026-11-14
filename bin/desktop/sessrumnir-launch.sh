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

# ── THE APPS RUN FROM MAIN, NOT FROM A WORKTREE (the Allfather, 2026-11-08: "are this the full apps. not
# just the start buttons?"). The launcher entries were only the visible half: the RUNTIME is this script,
# its node_modules, its built assets and the processes it raises. So a worktree re-executes the canonical
# tree's copy of this very script, and everything below it — Electron, the assets, the API — comes from main.
if [ -z "${YMIR_ALLOW_WORKTREE_RUNTIME:-}" ]; then
  # Compare ROOT with ROOT (2026-11-12): the old guard compared the canonical root with this script's own
  # folder, so from scripts/ it always fired and re-ran "<root>/electron.sh" (no such file) — every icon on
  # the pin died; from bin/desktop/ it looked for the resolver one level too high and never ran at all.
  _self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
  _root="$(dirname "$_self")"
  while [ "$_root" != / ] && [ ! -f "$_root/bin/desktop/main-tree.sh" ]; do _root="$(dirname "$_root")"; done
  _canon="$(bash "$_root/bin/desktop/main-tree.sh" "$_root" 2>/dev/null || true)"
  if [ -n "${_canon:-}" ] && [ "$_canon" != "$_root" ] && [ -f "$_canon/${_self#"$_root"/}" ]; then
    printf '%s: running from a WORKTREE — the app runtime is locked to main (%s), re-executing there\n' \
      "$(basename "$0")" "$_canon" >&2
    exec bash "$_canon/${_self#"$_root"/}" "$@"
  fi
fi

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
  pgrep -f "/electron/dist/electron .*sessrumnir" 2>/dev/null || true
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

# ── THE TREE AND ITS BUILD (plan 283 phase 4, 2026-11-13) ─────────────────────
# A launcher that opens a build older than its source tells the operator the APP is broken
# when only the BUILD is behind — and the source tree is where every repair is measured, so
# a fix "verified" in one tree and started from another is how tonight's ember stayed broken
# after being fixed. Two facts are printed (the tree, the build) and a stale build is
# REFUSED with the exact command, never rebuilt silently: a silent rebuild hides the drift.
# An installed package copy carries no `src/` next to `out/`; there the check says `package`
# and passes — a clean skip with its reason, never a green that hides a real tree.
mtime_of() {  # <path> -> epoch seconds, or nothing
  [ -e "$1" ] || return 0
  if stat -c %Y "$1" >/dev/null 2>&1; then stat -c %Y "$1"; else stat -f %m "$1" 2>/dev/null; fi
}
iso_of() {  # <epoch> -> local ISO minute
  [ -n "${1:-}" ] || { printf 'none'; return 0; }
  date -d "@$1" '+%Y-%m-%dT%H:%M' 2>/dev/null || date -r "$1" '+%Y-%m-%dT%H:%M' 2>/dev/null || printf 'none'
}
newest_source_mtime() {  # newest mtime among the app's sources
  local newest=0 m f
  for f in "$APP/package.json" "$APP/electron.vite.config.ts"; do
    m="$(mtime_of "$f")"; [ -n "$m" ] && [ "$m" -gt "$newest" ] && newest="$m"
  done
  if [ -d "$APP/src" ]; then
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      [ "$m" -gt "$newest" ] && newest="$m"
    done <<EOF
$(find "$APP/src" "$APP/resources" -type f -printf '%T@\n' 2>/dev/null | cut -d. -f1)
EOF
  fi
  [ "$newest" -gt 0 ] && printf '%s' "$newest"
}
# fresh | stale | unbuilt | package | unknown — and the two stamps, for the refusal line.
BUILD_STATE=""; BUILD_AT=""; SRC_AT=""
build_probe() {
  [ -n "$BUILD_STATE" ] && return 0
  local index="$APP/out/renderer/index.html" m_src m_out
  if [ ! -d "$APP/src" ] && [ -e "$APP/out/renderer/index.html" ]; then BUILD_STATE=package; return 0; fi
  if [ ! -e "$index" ]; then BUILD_STATE=unbuilt; return 0; fi
  m_src="$(newest_source_mtime)"; m_out="$(mtime_of "$index")"
  if [ -z "${m_src:-}" ] || [ -z "${m_out:-}" ]; then BUILD_STATE=unknown; return 0; fi
  SRC_AT="$(iso_of "$m_src")"; BUILD_AT="$(iso_of "$m_out")"
  if [ "$m_out" -lt "$m_src" ]; then BUILD_STATE=stale; else BUILD_STATE=fresh; fi
}
build_state() {
  build_probe
  case "$BUILD_STATE" in
    fresh) printf 'fresh %s' "$BUILD_AT" ;;
    stale) printf 'STALE build %s, source %s' "$BUILD_AT" "$SRC_AT" ;;
    unbuilt) printf 'unbuilt' ;;
    package) printf 'package copy' ;;
    *) printf 'unknown' ;;
  esac
}
build_refuse() {
  local cmd
  cmd="(cd $APP && npm run build)"
  printf 'error: Sessrúmnir will not start a build that is behind its source\n' >&2
  printf '  tree:   %s\n' "$APP" >&2
  if [ "$BUILD_STATE" = unbuilt ]; then
    printf '  build:  no out/renderer/index.html at all\n' >&2
  else
    printf '  build:  %s   source: %s\n' "$BUILD_AT" "$SRC_AT" >&2
  fi
  printf 'help: %s   (or start the pinned app: ymir-app sessrumnir — the pin is built at release)\n' "$cmd" >&2
  printf '      SESSRUMNIR_ALLOW_STALE=1 starts it anyway, and says so\n' >&2
}

# Raise the running window. The desktop-placement rule may have opened it on its
# own numbered desktop (desktop-place.sh), so a launch from elsewhere would
# otherwise show nothing — the focus dispatch also switches to where it sits.
# Omarchy configures Hyprland in Lua, so the dispatch is a Lua expression (the
# classic `focuswindow class:...` form does not parse).
focus_window() {
  [ "${SESSRUMNIR_NO_FOCUS:-0}" = 1 ] && return 0
  [ "${YMIR_APP_FOLLOWING:-0}" = 1 ] && return 0   # ymir-app brings it to the user's desktop (2026-11-14)
  command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl dispatch "hl.dsp.focus({window=\"class:^ymir-sessrumnir\$\"})" >/dev/null 2>&1 || true
}

case "$ACTION" in
  status)
    if is_running; then
      p="$(view_pids | head -1)"
      printf 'sessrumnir[1]{state,pid,tree,build}:\n  "up",%s,"%s","%s"\n' "$p" "$APP" "$(build_state)"
    else
      printf 'sessrumnir[1]{state,pid,tree,build}:\n  "down",0,"%s","%s"\n' "$APP" "$(build_state)"
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

# plan 271: a new window is not started over the operator's call (YMIR_DESK_NOW=1 is his "now").
# plan 275 S8: Sessrúmnir takes no microphone and loads no model, so a call does not hold it back

# A dead main leaves its helpers running as orphans of the user systemd. They
# still carry the identity string, so reaping them before the launch is the
# difference between a window and "started but nothing appeared".
stale="$(all_pids)"
if [ -n "$stale" ]; then
  printf '%s\n' "$stale" | while IFS= read -r p; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done
  sleep 1
fi

[ "${SESSRUMNIR_SKIP_ENSURE:-0}" = 1 ] || "$SCRIPT_DIR/../desktop/sessrumnir-ensure.sh" ensure --install >/dev/null 2>&1 || {
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
# The operator's own answers first (the home's config/desktop.env), then the machine policy.
desktop_env_load 2>/dev/null || true
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
export YMIR_DESKTOP_OZONE_PLATFORM="${YMIR_DESKTOP_OZONE_PLATFORM:-auto}"

START_TS="$(date -Is)"

if [ "${SESSRUMNIR_ALLOW_STALE:-0}" != 1 ]; then
  build_probe
  case "$BUILD_STATE" in
    stale|unbuilt) build_refuse; exit 1 ;;
  esac
fi

# ── THE PATH THE APP'S OWN SPAWNS INHERIT (plan 283, the seat fault, 2026-11-13) ──
# Measured: the Electron main process can arrive with NO PATH AT ALL (the launcher's child
# carried a 9 KB environment and not one PATH entry), so the app resolved `pi` to a bare
# npm global binary. That binary loads BOTH the pinned tree from the settings and this
# checkout's own `.pi/extensions`, every tool registers twice, and pi exits before a seat
# exists — the operator saw "Couldn't start Brokk". The house already has the one-home
# door (`~/.pi/agent/bin/pi`, RULES/13); it must be the FIRST pi on the child's PATH, and
# the rest of the seat's PATH is kept, never replaced.
export PATH="${HOME}/.pi/agent/bin:${PATH:-/usr/local/bin:/usr/bin:/bin}:${HOME}/.local/bin:${HOME}/.npm-global/bin"
printf '[launcher] tree=%s build=%s\n' "$APP" "$(build_state)" >>"$LOG_FILE"

nohup node "$APP/bin/sessrumnir.js" "${args[@]}" >"$LOG_FILE" 2>&1 < /dev/null &
LAUNCH_PID=$!
echo $LAUNCH_PID >"$PID_FILE"

# "up" means the window STAYED. The process appearing is not enough: on 2026-11-12 the launcher said
# "up" and the window was gone within seconds with an empty log (plan 271 piece 4). So the launcher
# waits for the process, then holds the claim for SESSRUMNIR_STAY_S seconds (default 10) and only then
# says "up"; if it is gone before that, it names what it can find — the app's own exit line, a core
# dump, the scope's end — in the log AND on stderr, and exits 1.
STAY_S="${SESSRUMNIR_STAY_S:-10}"
for _ in $(seq 1 30); do [ -n "$(view_pids)" ] && break; sleep 0.5; done

why_it_died() {
  local reason line core
  line="$(grep -E '^\[sessrumnir\] electron (exited|failed)' "$LOG_FILE" 2>/dev/null | tail -1)"
  [ -n "$line" ] && reason="$line" || reason="no exit line in the log (the launcher process itself $(kill -0 "$LAUNCH_PID" 2>/dev/null && echo 'is still alive, so no window ever mapped' || echo 'ended without saying why'))"
  if command -v coredumpctl >/dev/null 2>&1; then
    core="$(coredumpctl list --no-pager --no-legend --since "$START_TS" 2>/dev/null | grep -i electron | tail -1 | tr -s ' ' | cut -c1-120)"
    [ -n "$core" ] && reason="$reason; core dump: $core (coredumpctl info, or the diagnose-crash skill)"
  fi
  printf '%s' "$reason"
}

stayed=0
if [ -n "$(view_pids)" ]; then
  stayed=1
  t_end=$(( $(date +%s) + STAY_S ))
  while [ "$(date +%s)" -lt "$t_end" ]; do
    sleep 0.5
    if [ -z "$(view_pids)" ]; then stayed=0; break; fi
  done
fi

if [ "$stayed" = 1 ]; then
  focus_window
  printf 'sessrumnir[1]{state,pid,stayed_s}:\n  "up",%s,%s\n' "$(view_pids | head -1)" "$STAY_S"
else
  r="$(why_it_died)"
  printf '[launcher] the window did not stay up for %ss: %s\n' "$STAY_S" "$r" >>"$LOG_FILE"
  printf 'error: Sessrúmnir did not stay up (%ss): %s\nhelp: log %s\n' "$STAY_S" "$r" "${LOG_FILE#"$ROOT"/}" >&2
  exit 1
fi

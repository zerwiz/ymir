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

VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$ROOT/apps/hlidskjalf"
NO_INSTALL=0
VIEW="${YMIR_DESKTOP_VIEW:-hlidskjalf}"
VIEWS=(hlidskjalf smidja)

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-start}"; shift || true
while [ $# -gt 0 ]; do case "$1" in
  --no-install) NO_INSTALL=1; shift ;;
  --view) VIEW=${2-hlidskjalf}; shift 2 ;;
  --both) VIEW=both; shift ;;
  *) shift ;;
esac; done

pid_file() { case "$1" in smidja) printf '%s/state/electron-smidja.pid' "$ROOT" ;; *) printf '%s/state/electron.pid' "$ROOT" ;; esac; }
log_file() { case "$1" in smidja) printf '%s/state/electron-smidja.log' "$ROOT" ;; *) printf '%s/state/electron.log' "$ROOT" ;; esac; }
is_running() { local f; f="$(pid_file "$1")"; [ -r "$f" ] && kill -0 "$(tr -d '[:space:]' <"$f")" 2>/dev/null; }
pid_of() { tr -d '[:space:]' <"$(pid_file "$1")" 2>/dev/null; }

case "$ACTION" in
  status)
    printf 'electron[%s]{view,state,pid}:\n' "${#VIEWS[@]}"
    for v in "${VIEWS[@]}"; do
      if is_running "$v"; then printf '  "%s","up",%s\n' "$v" "$(pid_of "$v")"; else printf '  "%s","down",0\n' "$v"; fi
    done
    exit 0 ;;
  stop)
    for v in "${VIEWS[@]}"; do
      if is_running "$v"; then p=$(pid_of "$v"); kill "$p" 2>/dev/null || true; rm -f "$(pid_file "$v")"; printf 'electron: stopped %s pid=%s\n' "$v" "$p"; fi
    done
    printf 'electron: stopped\n'
    exit 0 ;;
  start|hlidskjalf|smidja) [ "$ACTION" = smidja ] && VIEW=smidja ;;
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

start_one() {
  local v="$1" f l
  f="$(pid_file "$v")"; l="$(log_file "$v")"
  if is_running "$v"; then printf 'electron[1]{view,state,pid}:\n  "%s","already up",%s\n' "$v" "$(pid_of "$v")"; return 0; fi
  nohup env YMIR_DESKTOP_VIEW="$v" "$APP/node_modules/.bin/electron" "$APP" >"$l" 2>&1 < /dev/null &
  echo $! >"$f"
}

if [ "$VIEW" = both ]; then
  start_one hlidskjalf
  start_one smidja
  sleep 2
  for v in "${VIEWS[@]}"; do
    if is_running "$v"; then printf 'electron[1]{view,state,pid,url}:\n  "%s","up",%s,"%s"\n' "$v" "$(pid_of "$v")" "$([ "$v" = smidja ] && echo http://127.0.0.1:8437/ || echo http://127.0.0.1:3888/)"; else printf 'error: electron %s failed to start; see %s\n' "$v" "${log_file "$v"#"$ROOT"/}" >&2; exit 1; fi
  done
else
  start_one "$VIEW"
  sleep 2
  if is_running "$VIEW"; then printf 'electron[1]{view,state,pid,url}:\n  "%s","up",%s,"%s"\n' "$VIEW" "$(pid_of "$VIEW")" "$([ "$VIEW" = smidja ] && echo http://127.0.0.1:8437/ || echo http://127.0.0.1:3888/)"; else printf 'error: electron failed to start; see %s\n' "${log_file "$VIEW"#"$ROOT"/}" >&2; exit 1; fi
fi

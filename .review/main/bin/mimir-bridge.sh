#!/usr/bin/env bash
# mimir-bridge.sh — raise/lower the well bridge (Mimirsbrunn on :4602).
# The engram engine speaks CLI + MCP; this keeps its HTTP face alive so the gate
# API, `bin/mimir.sh`, and the session start can drink from the well.
#
# Usage: bin/mimir-bridge.sh [--start|--stop|--status] [--port N] [--foreground]
#        bin/mimir-bridge.sh --foreground  # stay in the foreground (a systemd unit
#                                          # supervises this process directly — no self-daemon)
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "${ROOT:-}/bin/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/bin/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/hoard-lib.sh"; do
    [ -n "$_yc" ] && [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

# --- portability shim: bin/ymir-platform.sh --------------------------------
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  for _ymir_c in "$(git rev-parse --show-toplevel 2>/dev/null)/bin/ymir-platform.sh"                  "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/ymir-platform.sh"; do
    [ -n "$_ymir_c" ] && [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_c
fi

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
BRIDGE="$ROOT/bin/mimir-bridge.py"
# The well is ONE memory and it lives in the hoard — always. An explicit
# ENGRAM_DB is the operator's escape hatch; without it the hoard decides.
if [ -n "${ENGRAM_DB:-}" ]; then
  DB="$ENGRAM_DB"
else
  hoard_memory_store DB
fi
PORT="${MIMIRSBRUNN_PORT:-4602}"
PID_FILE="${YMIR_STATE_DIR:-$YMIR_HOME/state}/mimir-bridge.pid"
LOG_FILE="${YMIR_STATE_DIR:-$YMIR_HOME/state}/mimir-bridge.log"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="start"
FOREGROUND=0
while [ $# -gt 0 ]; do
  case "$1" in
    --start|"") ACTION=start; shift ;;
    --stop) ACTION=stop; shift ;;
    --status) ACTION=status; shift ;;
    --foreground) FOREGROUND=1; shift ;;
    --port) PORT=${2-}; shift 2 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/mimir-bridge.sh [--start|--stop|--status|--foreground]\n' "$1" >&2; exit 2 ;;
  esac
done

listening() { (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null && return 0 || return 1; }

case "$ACTION" in
  status)
    if listening; then printf 'well[1]{port,status}:\n  %s,"up"\n' "$PORT"; else printf 'well[1]{port,status}:\n  %s,"down"\n' "$PORT"; fi
    exit 0 ;;
  stop)
    stopped=0
    if [ -r "$PID_FILE" ]; then pid=$(tr -d '[:space:]' <"$PID_FILE"); if kill "$pid" 2>/dev/null; then stopped=1; fi; rm -f "$PID_FILE"; fi
    if listening; then ymir_kill_matching "bin/mimir-bridge.py" 2>/dev/null && stopped=1; fi
    if [ "$stopped" = 1 ]; then printf 'well: stopped\n'; else printf 'well: already stopped\n'; fi
    exit 0 ;;
esac

if listening; then
  pgrep -f "bin/mimir-bridge.py" >"$PID_FILE" 2>/dev/null || true
  printf 'well[1]{port,status}:\n  %s,"already up"\n' "$PORT"
  exit 0
fi
[ -e "$BRIDGE" ] || { printf 'error: bridge not found: %s\nhelp: expected bin/mimir-bridge.py\n' "$BRIDGE" >&2; exit 1; }
# engram needs Python >=3.12,<3.14, which the system python may not be. Prefer a
# recorded interpreter, then a compatible one on PATH, and only then python3.
PY="${YMIR_ENGRAM_PYTHON:-}"
if [ -z "$PY" ] && [ -r "${YMIR_ENGRAM_PY:-$HOME/.config/ymir/engram-python}" ]; then
  PY="$(cat "${YMIR_ENGRAM_PY:-$HOME/.config/ymir/engram-python}" 2>/dev/null)"
fi
if [ -z "$PY" ]; then
  for c in python3.12 python3.13; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done
fi
[ -n "$PY" ] || PY=python3

if ! "$PY" -c "import engram" 2>/dev/null; then
  printf 'error: engram not installed for %s\nhelp: bin/prereq-ensure.sh engram   (installs it into a compatible Python)\n' "$PY" >&2; exit 1
fi

mkdir -p "$YMIR_STATE_DIR" "$(dirname "$DB")"
if [ "$FOREGROUND" = 1 ]; then
  # A systemd unit owns this process: no self-daemon, no pid file, no port
  # poll — the bridge is the unit, and the unit's truth is the process's.
  exec env ENGRAM_DB="$DB" MIMIRSBRUNN_PORT="$PORT" "$PY" "$BRIDGE"
fi
ENGRAM_DB="$DB" MIMIRSBRUNN_PORT="$PORT" nohup "$PY" "$BRIDGE" >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
sleep 3
if listening; then
  printf 'well[1]{port,store,status}:\n  %s,"%s","started"\n' "$PORT" "${DB#"$ROOT"/}"
else
  printf 'error: well failed to start; see %s\n' "${LOG_FILE#"$ROOT"/}" >&2
  exit 1
fi

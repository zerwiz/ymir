#!/usr/bin/env bash
# mimir-bridge.sh — raise/lower the well bridge (Mimirsbrunn on :4602).
# The engram engine speaks CLI + MCP; this keeps its HTTP face alive so the gate
# API, `bin/mimir.sh`, and the session start can drink from the well.
#
# Usage: bin/mimir-bridge.sh [--start|--stop|--status] [--port N]
#        bin/mimir-bridge.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRIDGE="$ROOT/bin/mimir-bridge.py"
DB="${ENGRAM_DB:-$ROOT/.agents/memory/kaia.engram}"
PORT="${MIMIRSBRUNN_PORT:-4602}"
PID_FILE="$ROOT/state/mimir-bridge.pid"
LOG_FILE="$ROOT/state/mimir-bridge.log"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="start"
while [ $# -gt 0 ]; do
  case "$1" in
    --start|"") ACTION=start; shift ;;
    --stop) ACTION=stop; shift ;;
    --status) ACTION=status; shift ;;
    --port) PORT=${2-}; shift 2 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/mimir-bridge.sh [--start|--stop|--status]\n' "$1" >&2; exit 2 ;;
  esac
done

listening() { (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null && return 0 || return 1; }

case "$ACTION" in
  status)
    if listening; then printf 'well[1]{port,status}:\n  %s,"up"\n' "$PORT"; else printf 'well[1]{port,status}:\n  %s,"down"\n' "$PORT"; fi
    exit 0 ;;
  stop)
    if [ -r "$PID_FILE" ]; then pid=$(tr -d '[:space:]' <"$PID_FILE"); kill "$pid" 2>/dev/null || true; rm -f "$PID_FILE"; printf 'well: stopped pid=%s\n' "$pid"; else printf 'well: already stopped\n'; fi
    exit 0 ;;
esac

if listening; then
  printf 'well[1]{port,status}:\n  %s,"already up"\n' "$PORT"
  exit 0
fi
[ -e "$BRIDGE" ] || { printf 'error: bridge not found: %s\nhelp: expected bin/mimir-bridge.py\n' "$BRIDGE" >&2; exit 1; }
if ! python3 -c "import engram" 2>/dev/null; then
  printf 'error: engram not installed\nhelp: python3 -m pip install --user engram\n' >&2; exit 1
fi

mkdir -p "$ROOT/state" "$(dirname "$DB")"
ENGRAM_DB="$DB" MIMIRSBRUNN_PORT="$PORT" nohup python3 "$BRIDGE" >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
sleep 3
if listening; then
  printf 'well[1]{port,store,status}:\n  %s,"%s","started"\n' "$PORT" "${DB#"$ROOT"/}"
else
  printf 'error: well failed to start; see %s\n' "${LOG_FILE#"$ROOT"/}" >&2
  exit 1
fi

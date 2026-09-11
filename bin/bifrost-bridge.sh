#!/usr/bin/env bash
# bifrost-bridge.sh — raise/lower the model bridge (Bifrost: the bridge between
# realms). Pi's `opencode-go` provider points at a local OpenAI-compatible
# endpoint; this keeps that endpoint alive so a session never 401s.
#
# Usage: bin/bifrost-bridge.sh [--start|--stop|--status] [--port N]
#        bin/bifrost-bridge.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRIDGE="$ROOT/.agents/backend/opencode-go-bridge.py"
ENV_FILE="${BROKK_ENV_FILE:-$ROOT/.env.local}"
PORT="${OPENCODE_GO_BRIDGE_PORT:-4603}"
PID_FILE="$ROOT/state/model-bridge.pid"
LOG_FILE="$ROOT/state/model-bridge.log"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="start"
while [ $# -gt 0 ]; do
  case "$1" in
    --start|"") ACTION=start; shift ;;
    --stop) ACTION=stop; shift ;;
    --status) ACTION=status; shift ;;
    --port) PORT=${2-}; shift 2 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/bifrost-bridge.sh [--start|--stop|--status]\n' "$1" >&2; exit 2 ;;
  esac
done

listening() { (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null && return 0 || return 1; }

case "$ACTION" in
  status)
    if listening; then printf 'bridge[1]{port,status}:\n  %s,"up"\n' "$PORT"; else printf 'bridge[1]{port,status}:\n  %s,"down"\n' "$PORT"; fi
    exit 0 ;;
  stop)
    stopped=0
    if [ -r "$PID_FILE" ]; then pid=$(tr -d '[:space:]' <"$PID_FILE"); if kill "$pid" 2>/dev/null; then stopped=1; fi; rm -f "$PID_FILE"; fi
    if listening; then pkill -f "opencode-go-bridge.py" 2>/dev/null && stopped=1; fi
    if [ "$stopped" = 1 ]; then printf 'bridge: stopped\n'; else printf 'bridge: already stopped\n'; fi
    exit 0 ;;
esac

if listening; then
  pgrep -f "opencode-go-bridge.py" >"$PID_FILE" 2>/dev/null || true
  printf 'bridge[1]{port,status}:\n  %s,"already up"\n' "$PORT"
  exit 0
fi
[ -e "$BRIDGE" ] || { printf 'error: bridge script not found: %s\nhelp: expected .agents/backend/opencode-go-bridge.py\n' "$BRIDGE"; exit 1; }
if [ ! -r "$ENV_FILE" ]; then
  printf 'error: env file not found: %s\nhelp: put OPENCODE_GO_API_KEY in .env.local\n' "$ENV_FILE"; exit 1
fi

mkdir -p "$ROOT/state"
nohup python3 "$BRIDGE" --port "$PORT" --env "$ENV_FILE" >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
sleep 2
if listening; then
  printf 'bridge[1]{port,status}:\n  %s,"started"\n' "$PORT"
else
  printf 'error: bridge failed to start; see %s\nhelp: check OPENCODE_GO_API_KEY in %s\n' "${LOG_FILE#"$ROOT"/}" "${ENV_FILE#"$ROOT"/}" >&2
  exit 1
fi

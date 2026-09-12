#!/usr/bin/env bash
# bifrost-bridge.sh — raise/lower the model bridge (Bifrost: the bridge between
# realms). Pi's model provider points at a local OpenAI-compatible endpoint;
# this keeps that endpoint alive so a session never 401s.
#
# The provider is the operator's choice (YMIR_MODEL_PROVIDER):
#   opencode-go        OpenCode Zen Go gateway — needs OPENCODE_GO_API_KEY
#   lmstudio           LM Studio on localhost — keyless
#   openai-compatible  any OpenAI-compatible server — optional key
# No provider is forced to require a key: with no OPENCODE_GO_API_KEY the bridge
# auto-selects lmstudio so a fresh install with a local model server just works.
#
# Usage: bin/bifrost-bridge.sh [--start|--stop|--status] [--port N] [--provider NAME]
#        bin/bifrost-bridge.sh --version
set -u

# --- portability shim: bin/ymir-platform.sh --------------------------------
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  for _ymir_c in "$(git rev-parse --show-toplevel 2>/dev/null)/bin/ymir-platform.sh"                  "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/ymir-platform.sh"; do
    [ -n "$_ymir_c" ] && [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_c
fi

VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRIDGE="$ROOT/.agents/backend/model-bridge.py"
ENV_FILE="${BROKK_ENV_FILE:-$ROOT/.env.local}"
PORT="${OPENCODE_GO_BRIDGE_PORT:-4603}"
PID_FILE="$ROOT/state/model-bridge.pid"
LOG_FILE="$ROOT/state/model-bridge.log"
PROVIDER="${YMIR_MODEL_PROVIDER:-}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="start"
while [ $# -gt 0 ]; do
  case "$1" in
    --start|"") ACTION=start; shift ;;
    --stop) ACTION=stop; shift ;;
    --status) ACTION=status; shift ;;
    --port) PORT=${2-}; shift 2 ;;
    --provider) PROVIDER=${2-}; shift 2 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/bifrost-bridge.sh [--start|--stop|--status|--port|--provider]\n' "$1" >&2; exit 2 ;;
  esac
done

listening() { (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null && return 0 || return 1; }

# Read a key from the env file without sourcing it.
env_value() {
  local name="$1"
  [ -r "$ENV_FILE" ] || return 1
  sed -nE "s/^[[:space:]]*${name}[[:space:]]*=[[:space:]]*(.*)$/\1/p" "$ENV_FILE" \
    | tail -1 | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/'
}

case "$ACTION" in
  status)
    if listening; then
      printf 'bridge[1]{port,status,provider}:\n  %s,"up","%s"\n' "$PORT" "${PROVIDER:-auto}"
    else
      printf 'bridge[1]{port,status,provider}:\n  %s,"down","%s"\n' "$PORT" "${PROVIDER:-auto}"
    fi
    exit 0 ;;
  stop)
    stopped=0
    if [ -r "$PID_FILE" ]; then pid=$(tr -d '[:space:]' <"$PID_FILE"); if kill "$pid" 2>/dev/null; then stopped=1; fi; rm -f "$PID_FILE"; fi
    if listening; then ymir_kill_matching "model-bridge.py" 2>/dev/null && stopped=1; fi
    if [ "$stopped" = 1 ]; then printf 'bridge: stopped\n'; else printf 'bridge: already stopped\n'; fi
    exit 0 ;;
esac

if listening; then
  pgrep -f "model-bridge.py" >"$PID_FILE" 2>/dev/null || true
  printf 'bridge[1]{port,status}:\n  %s,"already up"\n' "$PORT"
  exit 0
fi
[ -e "$BRIDGE" ] || { printf 'error: bridge script not found: %s\nhelp: expected .agents/backend/model-bridge.py\n' "$BRIDGE"; exit 1; }

# Choose the provider when the operator did not pin one. Prefer an explicitly
# configured provider; otherwise use opencode-go only when a key actually
# exists, and fall back to the keyless local provider so install "just works".
if [ -z "$PROVIDER" ]; then
  if [ -n "$(env_value YMIR_MODEL_PROVIDER)" ]; then
    PROVIDER="$(env_value YMIR_MODEL_PROVIDER)"
  elif [ -n "$(env_value OPENCODE_GO_API_KEY)" ] || [ -n "${OPENCODE_GO_API_KEY:-}" ]; then
    PROVIDER="opencode-go"
  else
    PROVIDER="lmstudio"
  fi
fi

# A missing env file is fine for keyless providers; the bridge reads what it can.
mkdir -p "$ROOT/state"
nohup python3 "$BRIDGE" --port "$PORT" --env "$ENV_FILE" --provider "$PROVIDER" >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
sleep 2
if listening; then
  printf 'bridge[1]{port,status,provider}:\n  %s,"started","%s"\n' "$PORT" "$PROVIDER"
else
  printf 'error: bridge failed to start (provider=%s); see %s\n' "$PROVIDER" "${LOG_FILE#"$ROOT"/}" >&2
  case "$PROVIDER" in
    opencode-go) printf 'help: set OPENCODE_GO_API_KEY in %s, or run with --provider lmstudio\n' "${ENV_FILE#"$ROOT"/}" >&2 ;;
    lmstudio)    printf 'help: is LM Studio running and serving on 127.0.0.1:1234? Or set YMIR_MODEL_PROVIDER=opencode-go\n' >&2 ;;
    *)           printf 'help: check YMIR_MODEL_BASE_URL and the provider in %s\n' "${ENV_FILE#"$ROOT"/}" >&2 ;;
  esac
  exit 1
fi

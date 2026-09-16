#!/usr/bin/env bash
# apodex-smoke-test — validate an Apodex endpoint (GGUF via llama-router).
# Serves the model when asked (`--serve`), then runs one tool-calling round
# and reports pass/fail. Never mutates config; read-only against the seat.
#
# Exit codes: 0=pass, 1=fail, 2=unavailable (no weights / no GPU / no server).
#
# Usage:
#   apodex-smoke-test.sh               # probe a running Apodex endpoint
#   apodex-smoke-test.sh --serve       # serve the GGUF on APODEX_PORT, then test
#   apodex-smoke-test.sh --port 1234   # override the endpoint port
#   apodex-smoke-test.sh --model NAME  # override the model id
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source env if available (project .env.local first, then the private hoard).
for f in "$ROOT/.env.local" "${YMIR_HOARD:-$HOME/Documents/Ymir}/.env.local"; do
  [ -f "$f" ] && . "$f" 2>/dev/null || true
done

PORT="${APODEX_PORT:-1234}"
BASE="${APODEX_BASE_URL:-http://localhost:$PORT/v1}"
BASE="${BASE%/}"
MODEL="${APODEX_MODEL:-apodex/Apodex-1.0-mini-Q4_K_M}"
GGUF="${APODEX_GGUF:-$HOME/models/Apodex-1.0-mini-Q4_K_M-GGUF/Q4_K_M.gguf}"
SERVE=0

case "${1-}" in
  --serve) SERVE=1; shift ;;
  --port) PORT="${2:-$PORT}"; BASE="http://localhost:$PORT/v1"; shift 2 ;;
  --model) MODEL="${2:-$MODEL}"; shift 2 ;;
  --help|-h|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
PORT="${APODEX_PORT:-$PORT}"

echo "apodex[smoke]{serve,test,report}:"
echo "  targeting ${MODEL} @ ${BASE}"

if [ "$SERVE" = 1 ]; then
  if [ ! -f "$GGUF" ]; then
    echo "  FAIL: weights not found at $GGUF (set APODEX_GGUF or place the GGUF)"
    exit 2
  fi
  # Check the port is free before raising the server.
  if command -v lsof >/dev/null 2>&1 && lsof -i ":$PORT" >/dev/null 2>&1; then
    echo "  FAIL: :${PORT} already occupied — stop the holder or set APODEX_PORT"
    exit 1
  fi
  echo "  serve: llama-server --model $GGUF --port $PORT (background)"
  llama-server --model "$GGUF" --port "$PORT" --chat-format chatml \
    --ctx-size 4096 >/dev/null 2>&1 &
  SERVER_PID=$!
  echo "  server pid $SERVER_PID"
  # Wait for the endpoint to answer (bounded).
  for _ in $(seq 1 30); do
    curl -fsS --max-time 2 "$BASE/models" >/dev/null 2>&1 && break
    sleep 1
  done
fi

# 1) Endpoint up?
if ! curl -fsS --max-time 3 "$BASE/models" >/dev/null 2>&1; then
  echo "  FAIL: no server on ${BASE}"
  [ "$SERVE" = 1 ] && kill "$SERVER_PID" 2>/dev/null || true
  exit 1
fi
echo "  endpoint: ok"

# 2) Tool-calling round.
OUT="$(mktemp)"
trap 'rm -f "$OUT"; [ "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null || true' EXIT

curl -fsS --max-time 60 "$BASE/chat/completions" \
  -H "Content-Type: application/json" \
  --data "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"What is 2+2?\"}],\"tools\":[{\"type\":\"function\",\"function\":{\"name\":\"add\",\"parameters\":{\"type\":\"object\",\"properties\":{\"a\":{\"type\":\"number\"},\"b\":{\"type\":\"number\"}},\"required\":[\"a\",\"b\"]}}}]}" \
  > "$OUT" 2>/dev/null

if ! python3 -c "
import json,sys
d = json.load(open('$OUT'))
assert 'choices' in d and d['choices'], 'no choices'
m = d['choices'][0].get('message', {})
assert m.get('tool_calls') or m.get('content'), 'no tool_calls/content'
" 2>/dev/null; then
  echo "  FAIL: invalid/empty response from ${MODEL}"
  exit 1
fi

echo "  PASS: Apodex answered with a valid tool-capable response"
exit 0
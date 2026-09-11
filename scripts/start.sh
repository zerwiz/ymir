#!/usr/bin/env bash
# ============================================================
# YMIR — start the Hlidskjalf control plane (dev)
# Raises the SPA on http://127.0.0.1:3888/
# Usage: scripts/start.sh [--foreground]
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/apps/hlidskjalf"
RUN="$ROOT/.run"
PID_FILE="$RUN/hlidskjalf.pid"
LOG="$RUN/hlidskjalf.log"
PORT="${HLIDSKJALF_PORT:-3888}"

mkdir -p "$RUN"

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Hlidskjalf already running (pid $(cat "$PID_FILE")) → http://127.0.0.1:${PORT}/"
  exit 0
fi

if [[ ! -d "$APP/node_modules" ]]; then
  echo "Installing dependencies…"
  (cd "$APP" && npm install --no-audit --no-fund)
fi

# Raise the gate API (real runtime data) when bun is available. Demo mode works
# without it; live data needs it.
API_PORT="${HLIDSKJALF_API_PORT:-3889}"
API_PID_FILE="$RUN/hlidskjalf-api.pid"
API_LOG="$RUN/hlidskjalf-api.log"
if command -v bun >/dev/null 2>&1; then
  if [[ -f "$API_PID_FILE" ]] && kill -0 "$(cat "$API_PID_FILE")" 2>/dev/null; then
    echo "Gate API already running (pid $(cat "$API_PID_FILE")) → http://127.0.0.1:${API_PORT}/api/health"
  else
    setsid bun run "$APP/server/index.ts" >"$API_LOG" 2>&1 < /dev/null &
    echo $! > "$API_PID_FILE"
    for _ in $(seq 1 20); do
      curl -s -o /dev/null "http://127.0.0.1:${API_PORT}/api/health" && break
      sleep 0.5
    done
    echo "Gate API raised (pid $(cat "$API_PID_FILE")) → http://127.0.0.1:${API_PORT}/api/health"
  fi
else
  echo "bun not found — SPA will run; live data disabled (demo mode still works)." >&2
fi

# Runtime services: the Nornir schedule and the Bifrost model bridge.
if [ -x "$ROOT/bin/nornir-cron-start.sh" ]; then
  if "$ROOT/bin/nornir-cron-start.sh" >/dev/null 2>&1; then echo "Nornir cron: started"; else echo "Nornir cron: start failed" >&2; fi
fi
if [ -x "$ROOT/bin/bifrost-bridge.sh" ]; then
  if BROKK_ENV_FILE="$ROOT/.env.local" "$ROOT/bin/bifrost-bridge.sh" --start >/dev/null 2>&1; then echo "Bifrost bridge: up"; else echo "Bifrost bridge: not up (needs OPENCODE_GO_API_KEY)" >&2; fi
fi

cd "$APP"

if [[ "${1:-}" == "--foreground" ]]; then
  exec npm run dev
fi

# New session so we can signal the whole process group on stop.
setsid npm run dev >"$LOG" 2>&1 < /dev/null &
PID=$!
echo "$PID" > "$PID_FILE"

# Wait for the port to answer (max ~15s).
for _ in $(seq 1 30); do
  if curl -s -o /dev/null "http://127.0.0.1:${PORT}/"; then
    echo "Hlidskjalf raised (pid $PID) → http://127.0.0.1:${PORT}/"
    echo "Logs: $LOG"
    exit 0
  fi
  sleep 0.5
done

echo "Hlidskjalf started (pid $PID) but the port did not answer yet — check $LOG" >&2
exit 1

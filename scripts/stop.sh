#!/usr/bin/env bash
# ============================================================
# YMIR — stop the Hlidskjalf control plane
# Usage: scripts/stop.sh [--force]
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="$ROOT/.run"
PID_FILE="$RUN/hlidskjalf.pid"
API_PID_FILE="$RUN/hlidskjalf-api.pid"
PORT="${HLIDSKJALF_PORT:-3888}"
API_PORT="${HLIDSKJALF_API_PORT:-3889}"

stopped=0

# Gate API first — the SPA proxy points at it.
if [[ -f "$API_PID_FILE" ]]; then
  API_PID="$(cat "$API_PID_FILE")"
  if kill -0 "$API_PID" 2>/dev/null; then
    kill -TERM -- "-$API_PID" 2>/dev/null || kill -TERM "$API_PID" 2>/dev/null || true
    echo "Gate API stopped (pid $API_PID)."
    stopped=1
  fi
  rm -f "$API_PID_FILE"
fi

if [[ -f "$PID_FILE" ]]; then
  PID="$(cat "$PID_FILE")"
  if kill -0 "$PID" 2>/dev/null; then
    # Kill the whole process group (setup with setsid in start.sh).
    kill -TERM -- "-$PID" 2>/dev/null || kill -TERM "$PID" 2>/dev/null || true
    for _ in $(seq 1 20); do
      kill -0 "$PID" 2>/dev/null || break
      sleep 0.25
    done
    if kill -0 "$PID" 2>/dev/null && [[ "${1:-}" == "--force" ]]; then
      kill -KILL -- "-$PID" 2>/dev/null || kill -KILL "$PID" 2>/dev/null || true
    fi
    echo "Hlidskjalf stopped (pid $PID)."
    stopped=1
  fi
  rm -f "$PID_FILE"
fi

# Belt and braces: reap anything still bound to our port.
if command -v lsof >/dev/null 2>&1; then
  PORT_PIDS="$(lsof -ti "tcp:${PORT}" 2>/dev/null || true)"
  if [[ -n "$PORT_PIDS" ]]; then
    # shellcheck disable=SC2086
    kill -TERM $PORT_PIDS 2>/dev/null || true
    stopped=1
  fi
elif command -v fuser >/dev/null 2>&1; then
  fuser -k "${PORT}/tcp" 2>/dev/null && stopped=1 || true
fi

# Reap the gate API port too.
if command -v lsof >/dev/null 2>&1; then
  API_PIDS="$(lsof -ti "tcp:${API_PORT}" 2>/dev/null || true)"
  if [[ -n "$API_PIDS" ]]; then
    # shellcheck disable=SC2086
    kill -TERM $API_PIDS 2>/dev/null || true
    stopped=1
  fi
fi

if [[ "$stopped" -eq 0 ]]; then
  echo "Hlidskjalf is not running."
fi

if curl -s -o /dev/null "http://127.0.0.1:${PORT}/" 2>/dev/null; then
  echo "Warning: something still answers on port ${PORT}." >&2
  exit 1
fi

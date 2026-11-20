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
    # Kill the whole process group (detached in start.sh via the platform shim).
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

# Runtime services: the Nornir schedule and the Bifrost model bridge.
if [ -x "$ROOT/bin/nornir-cron-start.sh" ]; then
  "$ROOT/bin/nornir-cron-start.sh" --stop >/dev/null 2>&1 && { echo "Nornir cron stopped."; stopped=1; }
fi
if [ -x "$ROOT/bin/bifrost-bridge.sh" ]; then
  "$ROOT/bin/bifrost-bridge.sh" --stop >/dev/null 2>&1 && { echo "Bifrost bridge stopped."; stopped=1; }
fi
if [ -x "$ROOT/bin/mimir-bridge.sh" ]; then
  "$ROOT/bin/mimir-bridge.sh" --stop >/dev/null 2>&1 && { echo "Mimir bridge stopped."; stopped=1; }
fi

# Smíðja visualizer (API + UI).
for pair in "smidja-viz-api:Smíðja visualizer API" "smidja-viz-ui:Smíðja visualizer UI"; do
  file="${pair%%:*}"; label="${pair##*:}"
  pf="$RUN/$file.pid"
  if [[ -f "$pf" ]]; then
    pid="$(cat "$pf")"
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
      echo "$label stopped (pid $pid)."
      stopped=1
    fi
    rm -f "$pf"
  fi
done

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

# Reap the Smíðja visualizer ports (API :8437, UI :8438).
for p in "${SMIDJA_VIZ_API_PORT:-8437}" "${SMIDJA_VIZ_UI_PORT:-8438}"; do
  if command -v lsof >/dev/null 2>&1; then
    VIZ_PIDS="$(lsof -ti "tcp:${p}" 2>/dev/null || true)"
    if [[ -n "$VIZ_PIDS" ]]; then
      # shellcheck disable=SC2086
      kill -TERM $VIZ_PIDS 2>/dev/null || true
      stopped=1
    fi
  fi
done

if [[ "$stopped" -eq 0 ]]; then
  echo "Hlidskjalf is not running."
fi

if curl -s -o /dev/null "http://127.0.0.1:${PORT}/" 2>/dev/null; then
  echo "Warning: something still answers on port ${PORT}." >&2
  exit 1
fi

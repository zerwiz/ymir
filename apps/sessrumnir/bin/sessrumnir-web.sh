#!/usr/bin/env bash
# sessrumnir-web.sh — Headless web shell for Sessrúmnir
#
# Usage:
#   sessrumnir-web.sh start   # Start the web server
#   sessrumnir-web.sh stop    # Stop the web server
#   sessrumnir-web.sh status  # Check if running
#   sessrumnir-web.sh restart # Restart
#
# The server runs on a fixed port (3890) and serves:
#   - Built renderer files (out/renderer/)
#   - Bridge API (POST /api/<channel>)
#   - WebSocket events (WS /ws/<channel>)
#
# Port: 3890 (configurable via SESSRUNIR_WEB_PORT)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PID_FILE="${APP_DIR}/.sessrumnir-web.pid"
PORT="${SESSRUNIR_WEB_PORT:-3890}"
LOG_FILE="${APP_DIR}/.sessrumnir-web.log"

# ─── Functions ───────────────────────────────────────────────────────────────

start() {
  # Check if already running
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      echo "[Sessrúmnir Web] Already running (PID $pid on port $PORT)"
      return 0
    fi
  fi

  # Start the server
  echo "[Sessrúmnir Web] Starting on port $PORT..."
  cd "$APP_DIR"

  # Use Bun to run the server
  if command -v bun &>/dev/null; then
    bun run src/web-server.ts &
  elif command -v node &>/dev/null; then
    # Fallback: use tsx or node with esbuild
    node -r esbuild-register src/web-server.ts &
  else
    echo "[Sessrúmnir Web] Error: Neither bun nor node with esbuild-register found" >&2
    exit 1
  fi

  # Wait for server to start
  sleep 2

  # Capture the PID
  if [ -f "$PID_FILE" ]; then
    echo "[Sessrúmnir Web] Started (PID $(cat "$PID_FILE") on port $PORT)"
  else
    echo "[Sessrúmnir Web] Started on port $PORT"
  fi
}

stop() {
  if [ ! -f "$PID_FILE" ]; then
    echo "[Sessrúmnir Web] Not running"
    return 0
  fi

  local pid
  pid=$(cat "$PID_FILE")
  if kill -0 "$pid" 2>/dev/null; then
    echo "[Sessrúmnir Web] Stopping (PID $pid)..."
    kill "$pid"
    rm -f "$PID_FILE"
    echo "[Sessrúmnir Web] Stopped"
  else
    echo "[Sessrúmnir Web] Not running (stale PID file)"
    rm -f "$PID_FILE"
  fi
}

status() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      echo "[Sessrúmnir Web] Running (PID $pid on port $PORT)"
      return 0
    fi
  fi
  echo "[Sessrúmnir Web] Not running"
  return 1
}

# ─── Main ────────────────────────────────────────────────────────────────────

case "${1:-}" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  status)
    status
    ;;
  restart)
    stop
    sleep 1
    start
    ;;
  *)
    echo "Usage: $0 {start|stop|status|restart}"
    exit 1
    ;;
esac

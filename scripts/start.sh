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
  SPA_UP=1
else
  SPA_UP=0
fi

if [[ ! -d "$APP/node_modules" ]]; then
  echo "Installing dependencies…"
  (cd "$APP" && npm install --no-audit --no-fund)
fi

# NOTE: when the SPA is already up we still raise the API and the services
# below — the old early exit skipped them, leaving only :3888 listening.

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
# The well — Mimirsbrunn (engram) on :4602; the gate API and mimir.sh drink here.
if [ -x "$ROOT/bin/mimir-bridge.sh" ]; then
  if "$ROOT/bin/mimir-bridge.sh" --start >/dev/null 2>&1; then echo "Mimir bridge: up"; else echo "Mimir bridge: not up (needs engram)" >&2; fi
fi

# Smíðja's eye — the Vue trace visualizer (API :8437, UI :8438). Reads the repo's
# own smidja.db and exposes the Sessions/Trace/Decisions/Stats views behind the
# Hlidskjalf Sessions gate's "Open visualizer" button.
VIZ_DIR="$ROOT/.agents/skills/smidja/apps/visualizer"
VIZ_API_PORT="${SMIDJA_VIZ_API_PORT:-8437}"
VIZ_UI_PORT="${SMIDJA_VIZ_UI_PORT:-8438}"
VIZ_API_PID_FILE="$RUN/smidja-viz-api.pid"
VIZ_UI_PID_FILE="$RUN/smidja-viz-ui.pid"
SMIDJA_DB_PATH="${SMIDJA_DB:-$ROOT/smidja/smidja_data/smidja.db}"
if command -v bun >/dev/null 2>&1 && [ -d "$VIZ_DIR" ]; then
  [ -d "$VIZ_DIR/node_modules" ] || (cd "$VIZ_DIR" && bun install >/dev/null 2>&1 || true)
  # The API serves the UI from ./dist. Without a build it answers the API but
  # shows "No ./dist build found", so build once when dist is absent.
  if [ ! -d "$VIZ_DIR/dist" ]; then
    (cd "$VIZ_DIR" && bun run build >/dev/null 2>&1) || \
      echo "Smíðja visualizer UI build failed — run: (cd $VIZ_DIR && bun run build)" >&2
  fi
  if [ -f "$VIZ_API_PID_FILE" ] && kill -0 "$(cat "$VIZ_API_PID_FILE")" 2>/dev/null; then
    echo "Smíðja visualizer API already running (pid $(cat "$VIZ_API_PID_FILE")) → http://127.0.0.1:${VIZ_API_PORT}/"
  else
    setsid env CMD_DB="$SMIDJA_DB_PATH" PORT="$VIZ_API_PORT" bun run "$VIZ_DIR/server/index.ts" >"$RUN/smidja-viz-api.log" 2>&1 < /dev/null &
    echo $! > "$VIZ_API_PID_FILE"
    for _ in $(seq 1 20); do curl -s -o /dev/null "http://127.0.0.1:${VIZ_API_PORT}/api/health" && break; sleep 0.5; done
    echo "Smíðja visualizer API raised (pid $(cat "$VIZ_API_PID_FILE")) → http://127.0.0.1:${VIZ_API_PORT}/"
  fi
  if [ -f "$VIZ_UI_PID_FILE" ] && kill -0 "$(cat "$VIZ_UI_PID_FILE")" 2>/dev/null; then
    echo "Smíðja visualizer dev UI already running (pid $(cat "$VIZ_UI_PID_FILE")) → http://127.0.0.1:${VIZ_UI_PORT}/"
  elif [ "${SMIDJA_VIZ_DEV:-0}" = "1" ]; then
    # Opt-in Vite dev server for working on the visualizer itself.
    setsid bash -c "cd '$VIZ_DIR' && exec bunx vite --port ${VIZ_UI_PORT} --strictPort" >"$RUN/smidja-viz-ui.log" 2>&1 < /dev/null &
    echo $! > "$VIZ_UI_PID_FILE"
    for _ in $(seq 1 30); do curl -s -o /dev/null "http://127.0.0.1:${VIZ_UI_PORT}/" && break; sleep 0.5; done
    echo "Smíðja visualizer dev UI raised (pid $(cat "$VIZ_UI_PID_FILE")) → http://127.0.0.1:${VIZ_UI_PORT}/"
  else
    echo "Smíðja visualizer UI: served by the API at http://127.0.0.1:${VIZ_API_PORT}/"
  fi
else
  echo "Smíðja visualizer skipped (needs bun + $VIZ_DIR)." >&2
fi

cd "$APP"

if [[ "${1:-}" == "--foreground" ]]; then
  exec npm run dev
fi

# The SPA is already serving — nothing more for us to raise here.
if [[ "$SPA_UP" == "1" ]]; then
  echo "Hlidskjalf SPA already up → http://127.0.0.1:${PORT}/"
  exit 0
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

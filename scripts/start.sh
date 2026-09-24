#!/usr/bin/env bash
# ============================================================
# YMIR — start the Hlidskjalf control plane (dev)
# Raises the SPA on http://127.0.0.1:3888/
# Usage: scripts/start.sh [--foreground]
# ============================================================
set -euo pipefail

# --- portability shim: bin/ymir-platform.sh --------------------------------
# One place knows the OS differences (readlink -f, /proc, setsid, stat, nproc).
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  _ymir_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  for _ymir_c in "$_ymir_dir/ymir-platform.sh" "$(dirname "$_ymir_dir")/bin/ymir-platform.sh"; do
    [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_dir _ymir_c
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# bun installs to ~/.bun/bin and is often absent from a non-login PATH. Adopt it
# once, here, so the gate API and the Smiðja visualizer are not needlessly
# skipped — the installer already does this (bin/ymir-install.sh).
if ! command -v bun >/dev/null 2>&1 && [ -x "$HOME/.bun/bin/bun" ]; then
  PATH="$HOME/.bun/bin:$PATH"; export PATH
fi
# The cloth (bin/ymir-style.sh) — colour and words for the human watching.
if [ -z "${YMIR_STYLE_LOADED:-}" ] && [ -r "$ROOT/bin/ymir-style.sh" ]; then
  . "$ROOT/bin/ymir-style.sh"; YMIR_STYLE_LOADED=1; style_init
fi
# Where an app lives: apps/<surface> in a clone, node_modules/@zerwiz/<pkg> in an
# npm install — both shapes, one resolver (bin/app-lib.sh).
if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
  _ya="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yac in "$_ya/app-lib.sh" "$(dirname "$_ya")/bin/app-lib.sh"; do
    [ -r "$_yac" ] && { . "$_yac"; YMIR_APP_LIB_LOADED=1; break; }
  done
  unset _ya _yac
fi
app_dir hlidskjalf APP_HLIDSKJALF || APP_HLIDSKJALF=""
app_dir odrerir HALL_DIR || HALL_DIR=""

# Where the smithy's parts live: apps/smidja-factory in a clone, or the
# @zerwiz/smidja-factory package in an npm install (bin/smidja-lib.sh).
if [ -z "${YMIR_SMIDJA_LIB_LOADED:-}" ]; then
  _ys="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_ys/smidja-lib.sh" "$(dirname "$_ys")/bin/smidja-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_SMIDJA_LIB_LOADED=1; break; }
  done
  unset _ys _yc
fi
smidja_visualizer_dir SMIDJA_VIZ
smidja_factory_dir SMIDJA_FACTORY


# The operator's settings and secrets live in the home they chose, never in the
# code tree — a packaged install replaces its tree on upgrade, and a credential
# must never sit in a tree that ships (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
hoard_local_env YMIR_ENV_FILE
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
APP="$APP_HLIDSKJALF"
RUN="$ROOT/.run"
PID_FILE="$RUN/hlidskjalf.pid"
LOG="$RUN/hlidskjalf.log"

# Load the platform env once (Rule 04): the gate, the Bifrost bridge and Mimir
# all read their credentials from .env.local — 0600, gitignored, never printed.
# The bun gate reads process.env, and nothing loaded the file for it, so a
# credential set by bin/ymir-setup-auth.sh never reached it — and the gate treats
# an empty GATE_AUTH as "open". Loaded before the ports below so those may be
# overridden from it too.
if [ -r "$YMIR_ENV_FILE" ]; then
  set +eu
  set -a
  # shellcheck disable=SC1090,SC1091
  . "$YMIR_ENV_FILE" || true
  set +a
  set -eu
fi

PORT="${HLIDSKJALF_PORT:-3888}"

mkdir -p "$RUN"

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null && curl -s -o /dev/null --max-time 2 "http://127.0.0.1:${PORT}/" 2>/dev/null; then
  echo "Hlidskjalf already running (pid $(cat "$PID_FILE")) → http://127.0.0.1:${PORT}/"
  SPA_UP=1
else
  # A live pid is not a serving hall: a dev server bound to a foreign port (or
  # dead) answers nothing, and a stale pid file that passes `kill -0` would then
  # skip the raise and leave a window pointing at a dead URL. The port is the
  # truth; a pid that does not serve it is a ghost — purge its record (a guard
  # against killing an unrelated process: only the pid WE recorded is touched).
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Hlidskjalf pid $(cat "$PID_FILE") lives but :${PORT} does not answer — treating as stale, re-raising" >&2
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    sleep 0.5
  fi
  rm -f "$PID_FILE"
  SPA_UP=0
fi

if [[ ! -d "$APP/node_modules" ]]; then
  style_patience "the seat's own dependencies are being fetched, then the hall is raised"
echo "Installing dependencies…"
  (# Sessrúmnir — the seat-hall. Its own Electron app (not a browser surface), so it
# rises here rather than with the SPA: four surfaces, one raise.
if [ -x "$ROOT/bin/sessrumnir.sh" ]; then
  if app_dir sessrumnir APP_SESSRUMNIR; then
    if "$ROOT/bin/sessrumnir.sh" start >/dev/null 2>&1; then
      echo "Sessrúmnir — the seat-hall raised → (its own window)"
    else
      echo "Sessrúmnir — the seat-hall did not rise (run: bin/sessrumnir.sh start)" >&2
    fi
  else
    echo "Sessrúmnir — NOT raised: the sessrumnir surface is missing from this install" >&2
    echo "help: npm i -g @zerwiz/ymir (it is a dependency), or from a clone: bin/sessrumnir-ensure.sh install" >&2
  fi
fi

cd "$APP" && npm install --no-audit --no-fund)
fi

# NOTE: when the SPA is already up we still raise the API and the services
# below — the old early exit skipped them, leaving only :3888 listening.

# Raise the gate API (real runtime data) when bun is available. Demo mode works
# without it; live data needs it.
API_PORT="${HLIDSKJALF_API_PORT:-3889}"
# The public hostnames the gate fronts (written by bin/gjallarhorn-expose.sh):
# without them the gate cannot route a host to its app, and the login page for
# that app would never be reached.
[ -r "$YMIR_STATE_DIR/gjallarhorn-hosts.env" ] && . "$YMIR_STATE_DIR/gjallarhorn-hosts.env" && \
  export SMIDJA_HOST ODRERIR_HOST YMIR_PRIMARY_HOST
API_PID_FILE="$RUN/hlidskjalf-api.pid"
API_LOG="$RUN/hlidskjalf-api.log"
if command -v bun >/dev/null 2>&1; then
  if [[ -f "$API_PID_FILE" ]] && kill -0 "$(cat "$API_PID_FILE")" 2>/dev/null; then
    echo "Gate API already running (pid $(cat "$API_PID_FILE")) → http://127.0.0.1:${API_PORT}/api/health"
  else
    ymir_detach env PORT="$API_PORT" bun run "$APP/server/index.ts" >"$API_LOG" 2>&1
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
  if BROKK_ENV_FILE="$YMIR_ENV_FILE" "$ROOT/bin/bifrost-bridge.sh" --start >/dev/null 2>&1; then echo "Bifrost bridge: up"; else echo "Bifrost bridge: not up (needs OPENCODE_GO_API_KEY)" >&2; fi
fi
# The well — Mimirsbrunn (engram) on :4602; the gate API and mimir.sh drink here.
if [ -x "$ROOT/bin/mimir-bridge.sh" ]; then
  if "$ROOT/bin/mimir-bridge.sh" --start >/dev/null 2>&1; then echo "Mimir bridge: up"; else echo "Mimir bridge: not up (needs engram)" >&2; fi
fi

# Smíðja's eye — the Vue trace visualizer (API :8437, UI :8438). Reads the repo's
# own smidja.db and exposes the Sessions/Trace/Decisions/Stats views behind the
# Hlidskjalf Sessions gate's "Open visualizer" button.
VIZ_DIR="${SMIDJA_VIZ:-}"
VIZ_API_PORT="${SMIDJA_VIZ_API_PORT:-8437}"
VIZ_UI_PORT="${SMIDJA_VIZ_UI_PORT:-8438}"
VIZ_API_PID_FILE="$RUN/smidja-viz-api.pid"
VIZ_UI_PID_FILE="$RUN/smidja-viz-ui.pid"
SMIDJA_DB_PATH="${SMIDJA_DB:-}"
# The smithy DB follows the HOME: 0003-private-data-separation moved it to
# $YMIR_HOME/smidja/smidja.db. Prefer an existing DB there, then an in-repo copy
# for a checkout that keeps its own; SMIDJA_DB overrides either.
if [ -z "$SMIDJA_DB_PATH" ]; then
  for _db in "${YMIR_HOME:-$HOME/Documents/ymirhome}/smidja/smidja.db" \
             "$ROOT/apps/smidja/smidja_data/smidja.db"; do
    [ -f "$_db" ] && { SMIDJA_DB_PATH="$_db"; break; }
  done
  SMIDJA_DB_PATH="${SMIDJA_DB_PATH:-${YMIR_HOME:-$HOME/Documents/ymirhome}/smidja/smidja.db}"
fi
if command -v bun >/dev/null 2>&1 && [ -d "$VIZ_DIR" ]; then
  [ -d "$VIZ_DIR/node_modules" ] || (cd "$VIZ_DIR" && bun install >/dev/null 2>&1 || true)
  # The API serves the UI from ./dist. Without a build it answers the API but
  # shows "No ./dist build found", so build once when dist is absent.
  if [ ! -d "$VIZ_DIR/dist" ]; then
    # `bun run build` runs vue-tsc (typecheck) which may be absent; build with
    # vite directly first so the UI is produced even without the typechecker.
    (cd "$VIZ_DIR" && bunx vite build >/dev/null 2>&1) || \
      (cd "$VIZ_DIR" && bun run build >/dev/null 2>&1) || \
      echo "Smíðja visualizer UI build failed — run: (cd $VIZ_DIR && bunx vite build)" >&2
  fi
  if [ -f "$VIZ_API_PID_FILE" ] && kill -0 "$(cat "$VIZ_API_PID_FILE")" 2>/dev/null; then
    echo "Smíðja visualizer API already running (pid $(cat "$VIZ_API_PID_FILE")) → http://127.0.0.1:${VIZ_API_PORT}/"
  else
    ymir_detach env CMD_DB="$SMIDJA_DB_PATH" PORT="$VIZ_API_PORT" bun run "$VIZ_DIR/server/index.ts" >"$RUN/smidja-viz-api.log" 2>&1
    echo $! > "$VIZ_API_PID_FILE"
    for _ in $(seq 1 20); do curl -s -o /dev/null "http://127.0.0.1:${VIZ_API_PORT}/api/health" && break; sleep 0.5; done
    echo "Smíðja visualizer API raised (pid $(cat "$VIZ_API_PID_FILE")) → http://127.0.0.1:${VIZ_API_PORT}/"
  fi
  if [ -f "$VIZ_UI_PID_FILE" ] && kill -0 "$(cat "$VIZ_UI_PID_FILE")" 2>/dev/null; then
    echo "Smíðja visualizer dev UI already running (pid $(cat "$VIZ_UI_PID_FILE")) → http://127.0.0.1:${VIZ_UI_PORT}/"
  elif [ "${SMIDJA_VIZ_DEV:-0}" = "1" ]; then
    # Opt-in Vite dev server for working on the visualizer itself.
    ymir_detach bash -c "cd '$VIZ_DIR' && exec bunx vite --port ${VIZ_UI_PORT} --strictPort" >"$RUN/smidja-viz-ui.log" 2>&1
    echo $! > "$VIZ_UI_PID_FILE"
    for _ in $(seq 1 30); do curl -s -o /dev/null "http://127.0.0.1:${VIZ_UI_PORT}/" && break; sleep 0.5; done
    echo "Smíðja visualizer dev UI raised (pid $(cat "$VIZ_UI_PID_FILE")) → http://127.0.0.1:${VIZ_UI_PORT}/"
  else
    echo "Smíðja visualizer UI: served by the API at http://127.0.0.1:${VIZ_API_PORT}/"
  fi
else
  echo "Smíðja visualizer skipped (needs bun + $VIZ_DIR)." >&2
fi

# Óðrerir — the Live Hall. Its own Hlidskjalf-type board on :4322 — React +
# Vite, the ember cloth, the halls buttons (plan 55, 2026-09-24); the carved
# planning glass every hall door opens. Raised before the SPA so a window never
# waits.
app_dir odrerir HALL_DIR || HALL_DIR=""
HALL_PORT="${ODRERIR_PORT:-4322}"
HALL_PID_FILE="$RUN/odrerir.pid"
HALL_LOG="$RUN/odrerir.log"
if [ -d "$HALL_DIR" ] && [ -n "$HALL_DIR" ]; then
  # Its dependencies are not optional and their absence is not silent: a Vite
  # dev server without them dies with MODULE_NOT_FOUND while the raise claims it
  # was "raised" — the failure the truth-telling above exists to prevent.
  if [ ! -d "$HALL_DIR/node_modules" ]; then
    echo "Óðrerir — fetching its dependencies…"
    if ! (cd "$HALL_DIR" && npm install --no-audit --no-fund >/dev/null 2>&1); then
      echo "Óðrerir — Live Hall NOT raised: its dependencies could not be installed" >&2
      echo "help: (cd ${HALL_DIR#"$ROOT"/} && npm install)" >&2
      HALL_DIR=""
    fi
  fi
fi
if [ -n "$HALL_DIR" ] && [ -d "$HALL_DIR" ]; then
  if [ -f "$HALL_PID_FILE" ] && kill -0 "$(cat "$HALL_PID_FILE")" 2>/dev/null; then
    echo "Óðrerir — Live Hall already running (pid $(cat "$HALL_PID_FILE")) → http://127.0.0.1:${HALL_PORT}/"
  else
    # A packaged app ships a BUILD (odrerir's tarball carries dist/, and vite is
    # hoisted by the workspace-root install — the P3 law). Serve the build where
    # there is one; develop where there is not.
    if [ -d "$HALL_DIR/dist" ]; then
      ymir_detach bash -c "cd '$HALL_DIR' && exec npx --no-install vite preview --port '$HALL_PORT' --host" >"$HALL_LOG" 2>&1
    else
      ymir_detach bash -c "cd '$HALL_DIR' && exec npm run dev -- --port '$HALL_PORT' --host" >"$HALL_LOG" 2>&1
    fi
    echo $! > "$HALL_PID_FILE"
    _hall_up=0
    for _ in $(seq 1 40); do
      curl -s -o /dev/null "http://127.0.0.1:${HALL_PORT}/" && { _hall_up=1; break; }
      kill -0 "$(cat "$HALL_PID_FILE")" 2>/dev/null || break
      sleep 0.5
    done
    if [ "$_hall_up" = 1 ]; then
      echo "Óðrerir — Live Hall raised (pid $(cat "$HALL_PID_FILE")) → http://127.0.0.1:${HALL_PORT}/"
    else
      echo "Óðrerir — Live Hall started (pid $(cat "$HALL_PID_FILE")) but :${HALL_PORT} did not answer — see $HALL_LOG" >&2
      tail -5 "$HALL_LOG" >&2 2>/dev/null || true
    fi
  fi
else
  echo "Óðrerir — NOT raised: the odrerir surface is missing from this install" >&2
  echo "help: npm i -g @zerwiz/ymir (it is a dependency)" >&2
fi

cd "$APP"

if [[ "${1:-}" == "--foreground" ]]; then
  if [ -d "$APP/dist" ]; then exec npx --no-install vite preview --port "$PORT" --strictPort --host
  else exec npm run dev -- --port "$PORT" --strictPort --host; fi
fi

# The SPA is already serving — nothing more for us to raise here.
if [[ "$SPA_UP" == "1" ]]; then
  echo "Hlidskjalf SPA already up → http://127.0.0.1:${PORT}/"
  exit 0
fi

# New session so we can signal the whole process group on stop.
# The port is OUR decision, not Vite's: a bare `npm run dev` takes 5173 and the
# hall never answers on the port every other door expects. A packaged install
# ships ./dist, so it is served; a clone gets the dev server — both on $PORT.
if [ -d "$APP/dist" ]; then
  ymir_detach bash -c "cd '$APP' && exec npx --no-install vite preview --port '$PORT' --strictPort --host" >"$LOG" 2>&1
else
  ymir_detach bash -c "cd '$APP' && exec npm run dev -- --port '$PORT' --strictPort --host" >"$LOG" 2>&1
fi
PID=$!
echo "$PID" > "$PID_FILE"

# Wait for the port to answer (max ~15s), then say what is true.
for _ in $(seq 1 30); do
  if curl -s -o /dev/null "http://127.0.0.1:${PORT}/"; then
    # The windows — the raise opens all four when a display is present, so
    # 'ymir raise' stands the whole hall: the high seat, the board, the
    # smithy's eye, and the seat-hall.
    if [ -n "${WAYLAND_DISPLAY:-${DISPLAY:-}}" ]; then
      "$ROOT/scripts/electron.sh" start --view hlidskjalf >/dev/null 2>&1 &
      "$ROOT/scripts/electron.sh" start --view odrerir >/dev/null 2>&1 &
      "$ROOT/scripts/electron.sh" start --view smidja >/dev/null 2>&1 &
      "$ROOT/bin/ymir.js" sessrumnir >/dev/null 2>&1 &
    fi
    echo "Hlidskjalf raised (pid $PID) → http://127.0.0.1:${PORT}/"
    echo "Logs: $LOG"
    exit 0
  fi
  sleep 0.5
done

echo "Hlidskjalf started (pid $PID) but :${PORT} did not answer — see $LOG" >&2
tail -5 "$LOG" >&2 2>/dev/null || true
exit 1

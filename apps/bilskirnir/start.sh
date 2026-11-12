#!/usr/bin/env bash
# start.sh — raise Bilskirnir in ONE command, in the ONE order that works.
#
#   apps/bilskirnir/start.sh             raise: setup · Nanna's gateway · the face · the server · the window
#   apps/bilskirnir/start.sh --headless  the same, with no window (open the hall in a browser)
#   apps/bilskirnir/start.sh --dev       the face from Vite (hot reload) instead of the built one
#   apps/bilskirnir/start.sh --check     report what is up, change nothing (exit 1 when the hall is not)
#   apps/bilskirnir/start.sh --stop      lower what this script raised — and nothing it did not
#
# The order, and why it is the only one:
#   1 · setup     the agent's home, .env and the dependencies must exist before anything reads them
#   2 · gateway   Nanna's Hermes gateway first: the server asks it for her state the moment it boots,
#                 and a server that boots into a silent gateway shows "not answering" until restarted
#   3 · the face  built once into web/dist when the sources are newer, so the server serves it on its
#                 own origin (one port, no Vite) — or, with --dev, Vite in front of the server
#   4 · server    the hall's own server, which also serves the face
#   5 · window    the Electron shell, which waits for the server and opens it
#
# A piece that is already answering is KEPT, never restarted: the hall may be in use. --stop lowers
# only the processes whose pid this script wrote under data/run/; it never kills by pattern.
#
# Settings (RULES/07), each with one documented default:
#   PORT (in .env)            the server's port                 (8787)
#   BILSKIRNIR_WEB_PORT       Vite's port with --dev            (5173)
#   BILSKIRNIR_ELECTRON       the electron binary               (probed: node_modules, /usr/lib/electron*, PATH)
#   HERMES_BIN (in .env)      the hermes CLI                    (hermes)
#   BILSKIRNIR_DEBUG_PORT     open the window's DevTools port   (unset: closed)
set -uo pipefail
APP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="$APP/data/run"; mkdir -p "$RUN"
say() { printf '%-28s %s\n' "$1" "$2"; }
envval() { grep -E "^$1=" "$2" 2>/dev/null | tail -1 | cut -d= -f2-; }

PORT="$(envval PORT "$APP/.env")"; PORT="${PORT:-8787}"
WEB_PORT="${BILSKIRNIR_WEB_PORT:-5173}"
HERMES_BIN="$(envval HERMES_BIN "$APP/.env")"; HERMES_BIN="${HERMES_BIN:-hermes}"
ENGINE="$(envval HERMES_HOME_PRIMARY "$APP/.env")"
HPORT="$(envval API_SERVER_PORT "$ENGINE/.env")"; HPORT="${HPORT:-8642}"
URL="http://127.0.0.1:$PORT"

# The electron binary is PROBED, never pinned to one distro release (Rödd learned this: electron41 →
# electron43 turned a hard path into "No such file").
resolve_electron() {
  [ -n "${BILSKIRNIR_ELECTRON:-}" ] && { printf '%s' "$BILSKIRNIR_ELECTRON"; return 0; }
  local e
  for e in "$APP/node_modules/electron/dist/electron" "$APP/../rodd/node_modules/electron/dist/electron"; do
    [ -x "$e" ] && { printf '%s' "$e"; return 0; }
  done
  for e in $(ls -d /usr/lib/electron*/electron 2>/dev/null | sort -Vr); do
    [ -x "$e" ] && { printf '%s' "$e"; return 0; }
  done
  command -v electron 2>/dev/null
}

up() { curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$1" 2>/dev/null | grep -q '^2'; }
gateway_up() { up "http://127.0.0.1:$HPORT/health" || up "http://127.0.0.1:$HPORT/v1/models"; }
alive() { [ -f "$RUN/$1.pid" ] && kill -0 "$(cat "$RUN/$1.pid")" 2>/dev/null; }
window_up() { alive window; }
# Every piece runs in its own session whose leader writes its own pid, so --stop can lower the whole
# group (npx → node, hermes → its children) with one signal and never touch anything else.
spawn() {
  local name="$1" dir="$2"; shift 2
  setsid bash -c 'echo $$ > "$0"; cd "$1" || exit 1; shift 2; exec "$@"' "$RUN/$name.pid" "$dir" -- "$@" \
    > "$RUN/$name.log" 2>&1 < /dev/null &
  sleep 0.3
}
wait_for() { local i; for i in $(seq 1 "$2"); do eval "$1" && return 0; sleep 1; done; return 1; }

lower() {
  local name="$1" pid
  if alive "$name"; then
    pid="$(cat "$RUN/$name.pid")"
    kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null
    local i; for i in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$pid" 2>/dev/null || break; sleep 0.5; done
    say "lowered" "$name (pid $pid)"
  fi
  rm -f "$RUN/$name.pid"
}

case "${1:-}" in
  -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --stop)
    for n in window server web gateway; do lower "$n"; done
    say "the hall" "lowered (what this script raised)"
    exit 0 ;;
  --check)
    ok=0
    gateway_up && say "Nanna's gateway :$HPORT" "answers" || { say "Nanna's gateway :$HPORT" "silent"; ok=1; }
    up "$URL/api/health" && say "the server :$PORT" "answers" || { say "the server :$PORT" "silent"; ok=1; }
    [ -f "$APP/web/dist/index.html" ] && say "the face" "built (web/dist)" || say "the face" "not built — the server serves the API only"
    window_up && say "the window" "open" || say "the window" "closed"
    e="$(resolve_electron)"; say "electron" "${e:-none found}"
    exit "$ok" ;;
esac

MODE="window"; [ "${1:-}" = "--headless" ] && MODE="headless"; [ "${1:-}" = "--dev" ] && MODE="dev"

# 1 · setup (only when something is stale — setup never empties a running app's floor)
if ! "$APP/setup.sh" --check >/dev/null 2>&1; then
  say "setup" "stale — running apps/bilskirnir/setup.sh"
  "$APP/setup.sh" | tail -2 || { say "setup" "FAILED — run apps/bilskirnir/setup.sh by hand"; exit 1; }
  ENGINE="$(envval HERMES_HOME_PRIMARY "$APP/.env")"; HPORT="$(envval API_SERVER_PORT "$ENGINE/.env")"; HPORT="${HPORT:-8642}"
else
  say "setup" "current"
fi

# 2 · Nanna's gateway, in her own Hermes home (never ~/.hermes)
if gateway_up; then
  say "Nanna's gateway :$HPORT" "already answers — kept"
elif ! command -v "$HERMES_BIN" >/dev/null 2>&1; then
  say "Nanna's gateway" "no '$HERMES_BIN' on PATH — the hall opens, and Nanna stays silent"
else
  HERMES_HOME="$ENGINE" spawn gateway "$ENGINE" "$HERMES_BIN" gateway run --no-supervise
  wait_for gateway_up 60 && say "Nanna's gateway :$HPORT" "raised" || say "Nanna's gateway :$HPORT" "not answering yet — see data/run/gateway.log"
fi

# 3 · the face
if [ "$MODE" = "dev" ]; then
  if up "http://127.0.0.1:$WEB_PORT/"; then say "the face (Vite) :$WEB_PORT" "already answers — kept"
  else
    GROKBOT_API="$URL" spawn web "$APP/web" npx vite --port "$WEB_PORT"
    wait_for "up http://127.0.0.1:$WEB_PORT/" 30 && say "the face (Vite) :$WEB_PORT" "raised" || say "the face (Vite)" "not answering — see data/run/web.log"
  fi
else
  newest_src="$(find "$APP/web/src" "$APP/web/index.html" "$APP/web/public" -type f -newer "$APP/web/dist/index.html" 2>/dev/null | head -1)"
  if [ ! -f "$APP/web/dist/index.html" ] || [ -n "$newest_src" ]; then
    ( cd "$APP/web" && npx vite build > "$RUN/build.log" 2>&1 ) && say "the face" "built into web/dist" || { say "the face" "build FAILED — see data/run/build.log"; exit 1; }
  else
    say "the face" "built and current"
  fi
fi

# 4 · the server
if up "$URL/api/health"; then
  say "the server :$PORT" "already answers — kept"
else
  spawn server "$APP/server" npx tsx --env-file=../.env src/index.ts
  wait_for "up $URL/api/health" 40 && say "the server :$PORT" "raised" || { say "the server :$PORT" "FAILED — see data/run/server.log"; exit 1; }
fi

OPEN_URL="$URL"; [ "$MODE" = "dev" ] && OPEN_URL="http://127.0.0.1:$WEB_PORT"

# 5 · the window
if [ "$MODE" = "headless" ]; then
  say "the window" "skipped (headless) — open $OPEN_URL"
  exit 0
fi
if window_up; then say "the window" "already open — kept"; exit 0; fi
ELECTRON="$(resolve_electron)"
[ -n "$ELECTRON" ] || { say "the window" "no electron binary — install electron, or open $OPEN_URL in a browser"; exit 1; }
DEBUG=(); [ -n "${BILSKIRNIR_DEBUG_PORT:-}" ] && DEBUG=(--remote-debugging-port="$BILSKIRNIR_DEBUG_PORT")
BILSKIRNIR_URL="$OPEN_URL" spawn window "$APP" "$ELECTRON" "${DEBUG[@]}" "$APP/electron"
sleep 2
window_up && say "the window" "open ($OPEN_URL)" || say "the window" "did not stay open — see data/run/window.log"
say "lower it" "apps/bilskirnir/start.sh --stop"

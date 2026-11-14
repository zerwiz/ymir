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
# A piece that is already answering AND is ours is KEPT, never restarted: the hall may be in use.
# Ours means the listener sits in the process group of the pid this script wrote under data/run/, or
# its working directory is inside this app's tree. A port held by anything else is a STRANGER: it is
# named by pid and directory, never "kept". A stranger that is another Bilskirnir tree of this user
# is lowered and replaced; any other stranger is refused with the exact command to lower it.
# The server counts as up only when GET / serves the built face, not merely when the port answers.
# --stop lowers only the processes whose pid this script wrote under data/run/; never by pattern.
#
# Settings (RULES/07), each with one documented default:
#   PORT (in .env)            the server's port                 (8787)
#   BILSKIRNIR_WEB_PORT       Vite's port with --dev            (5173)
#   BILSKIRNIR_ELECTRON       the electron binary               (probed: node_modules, /usr/lib/electron*, PATH)
#   HERMES_BIN (in .env)      the hermes CLI                    (hermes)
#   BILSKIRNIR_DEBUG_PORT     open the window's DevTools port   (unset: closed)
set -uo pipefail
APP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# the hall's state lives in one home per user, never in this checkout (plan 275 S5)
[ "${1:-}" = "--check" ] || bash "$APP/scripts/data-home.sh" || { echo "bilskirnir: the data home could not be linked — see scripts/data-home.sh" >&2; exit 1; }
RUN="$APP/data/run"; mkdir -p "$RUN"
say() { printf '%-28s %s\n' "$1" "$2"; }
envval() { grep -E "^$1=" "$2" 2>/dev/null | tail -1 | cut -d= -f2-; }

PORT="$(envval PORT "$APP/.env")"; PORT="${PORT:-8787}"
WEB_PORT="${BILSKIRNIR_WEB_PORT:-5173}"
HERMES_BIN="$(envval HERMES_BIN "$APP/.env")"; HERMES_BIN="${HERMES_BIN:-hermes}"
ENGINE="$(envval HERMES_HOME_PRIMARY "$APP/.env")"
# plan 275 (2026-11-13): an agent's Hermes home is named by its PHYSICAL path. Hermes ties a profile to the home
# path it was given; a home named through the pin (~/ymir-runtime → releases/<sha>) changes its name at every
# release and Hermes refuses every message with profile_mismatch (Nanna from 2026-11-12 19:26).
[ -d "$ENGINE" ] && ENGINE="$(cd "$ENGINE" && pwd -P)"
HPORT="$(envval API_SERVER_PORT "$ENGINE/.env")"; HPORT="${HPORT:-8642}"
URL="http://127.0.0.1:$PORT"

# The electron binary is PROBED, never pinned to one distro release (Rödd learned this: electron41 →
# electron43 turned a hard path into "No such file").
resolve_electron() {
  # plan 275 S10 (2026-11-12): the ONE resolver (bin/desktop/electron-lib.sh), the release's own Electron only. The
  # old probe fell back to another app's runtime and to the distribution's /usr/lib/electron*, which pacman upgrades
  # on its own schedule — so an app ran on whatever Electron was lying around, and broke when that moved.
  [ -n "${BILSKIRNIR_ELECTRON:-}" ] && { printf '%s' "$BILSKIRNIR_ELECTRON"; return 0; }
  local tree; tree="$(dirname "$(dirname "$APP")")"
  [ -r "$tree/bin/desktop/electron-lib.sh" ] || return 1
  ( . "$tree/bin/desktop/electron-lib.sh"; electron_bin "$APP" "$tree" )
}

face_up() { curl -s --max-time 2 -w '\n%{http_code}' "$1/" 2>/dev/null | awk 'BEGIN{b="";c=""} {if(c!="")b=b c "\n"; c=$0} END{exit !(c ~ /^2/ && tolower(b) ~ /<!doctype html|<div id=/)}'; }
up() { curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$1" 2>/dev/null | grep -q '^2'; }
gateway_up() { up "http://127.0.0.1:$HPORT/health" || up "http://127.0.0.1:$HPORT/v1/models"; }
# Who listens on a port: the pids, one per line (ss first, lsof as a fallback; empty when free or unknown).
listeners() {
  { ss -ltnpH "sport = :$1" 2>/dev/null | grep -o 'pid=[0-9]*' | cut -d= -f2
    command -v ss >/dev/null 2>&1 || lsof -tiTCP:"$1" -sTCP:LISTEN 2>/dev/null; } | sort -un
}
port_free() { [ -z "$(listeners "$1")" ]; }
pid_cwd() { readlink "/proc/$1/cwd" 2>/dev/null; }
under() { case "$1/" in "$2"/*) return 0 ;; esac; return 1; }
# ours: the listener is in the group of the pid we wrote, or works inside our own tree (or our engine home).
is_ours() {
  local name="$1" pid="$2" lead cwd
  if [ -f "$RUN/$name.pid" ]; then
    lead="$(cat "$RUN/$name.pid")"
    [ "$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')" = "$lead" ] && return 0
  fi
  cwd="$(pid_cwd "$pid")"; [ -n "$cwd" ] || return 1
  under "$cwd" "$APP" && return 0
  [ -n "$ENGINE" ] && under "$cwd" "$ENGINE" && return 0
  return 1
}
# Another Bilskirnir tree of this same user: the process is ours by uid and works in .../apps/bilskirnir/...
is_sibling_tree() {
  local pid="$1" cwd; cwd="$(pid_cwd "$pid")"
  [ "$(stat -c %u "/proc/$pid" 2>/dev/null)" = "$(id -u)" ] || return 1
  case "$cwd/" in */apps/bilskirnir/*) return 0 ;; esac; return 1
}
# claim <name> <port> <label>: 0 = ours and answering (keep) · 1 = free (raise it) · 2 = refused.
# A stranger that is a sibling Bilskirnir tree is lowered here, and the port reads as free.
claim() {
  local name="$1" port="$2" label="$3" pids pid cwd mine=0 stranger="" i
  pids="$(listeners "$port")"
  [ -n "$pids" ] || return 1
  for pid in $pids; do
    if is_ours "$name" "$pid"; then mine=1; else stranger="$pid"; fi
  done
  [ -z "$stranger" ] && [ "$mine" = 1 ] && return 0
  cwd="$(pid_cwd "$stranger")"
  if is_sibling_tree "$stranger"; then
    say "$label :$port" "held by another Bilskirnir tree (pid $stranger, ${cwd:-?}) — lowering it"
    kill "$stranger" 2>/dev/null
    for i in 1 2 3 4 5 6 7 8 9 10; do port_free "$port" && break; sleep 0.5; done
    port_free "$port" && return 1
    say "$label :$port" "still held by pid $stranger after SIGTERM — lower it: kill -9 $stranger"; return 2
  fi
  say "$label :$port" "STRANGER on the port: pid $stranger (${cwd:-cwd unreadable}), not this app's — refusing to keep or kill it"
  say "  to lower it" "kill $stranger   (then run apps/bilskirnir/start.sh again)"
  return 2
}
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
    local i
    if [ "$name" = window ]; then
      # plan 275 (2026-11-13): the window is closed through its MAIN process and given time to close its own helpers.
      # Killing the whole group at once kills the GPU and renderer helpers under it, and Electron traps (SIGTRAP core
      # at 13:22:09, the operator's window). The group is killed only if it will not close in five seconds.
      kill -TERM "$pid" 2>/dev/null
      for i in $(seq 1 10); do kill -0 -- "-$pid" 2>/dev/null || break; sleep 0.5; done
      kill -0 -- "-$pid" 2>/dev/null && kill -KILL -- "-$pid" 2>/dev/null
    else
      kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null
      for i in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$pid" 2>/dev/null || break; sleep 0.5; done
    fi
    say "lowered" "$name (pid $pid)"
  fi
  rm -f "$RUN/$name.pid"
}

case "${1:-}" in
  -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --stop)
    for n in window server web gateway; do lower "$n"; done
    say "the hall" "lowered (what this script raised)"
    exit 0 ;;
  --check)
    ok=0
    gateway_up && say "Nanna's gateway :$HPORT" "answers" || { say "Nanna's gateway :$HPORT" "silent"; ok=1; }
    if up "$URL/api/health"; then
      say "the server :$PORT" "answers"
      face_up "$URL" && say "the face at $URL/" "served" || { say "the face at $URL/" "NOT served — a server without the built face (a stranger?)"; ok=1; }
      for pid in $(listeners "$PORT"); do is_ours server "$pid" || { say "the server :$PORT" "pid $pid is a STRANGER ($(pid_cwd "$pid"))"; ok=1; }; done
    else say "the server :$PORT" "silent"; ok=1; fi
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
  ENGINE="$(envval HERMES_HOME_PRIMARY "$APP/.env")"; [ -d "$ENGINE" ] && ENGINE="$(cd "$ENGINE" && pwd -P)"; HPORT="$(envval API_SERVER_PORT "$ENGINE/.env")"; HPORT="${HPORT:-8642}"
else
  say "setup" "current"
fi

# 2 · Nanna's gateway, in her own Hermes home (never ~/.hermes)
claim gateway "$HPORT" "Nanna's gateway"; gc=$?
if [ "$gc" = 2 ]; then exit 1
elif [ "$gc" = 0 ] && gateway_up; then
  say "Nanna's gateway :$HPORT" "already answers — kept (ours)"
elif ! command -v "$HERMES_BIN" >/dev/null 2>&1; then
  say "Nanna's gateway" "no '$HERMES_BIN' on PATH — the hall opens, and Nanna stays silent"
else
  python3 "$APP/house/hermes-rebind.py" "$ENGINE" >/dev/null 2>&1 || true   # receipts follow the home (plan 275)
  HERMES_HOME="$ENGINE" spawn gateway "$ENGINE" "$HERMES_BIN" gateway run --no-supervise
  wait_for gateway_up 60 && say "Nanna's gateway :$HPORT" "raised" || say "Nanna's gateway :$HPORT" "not answering yet — see data/run/gateway.log"
fi

# 3 · the face
if [ "$MODE" = "dev" ]; then
  claim web "$WEB_PORT" "the face (Vite)"; wc=$?
  [ "$wc" = 2 ] && exit 1
  if [ "$wc" = 0 ] && up "http://127.0.0.1:$WEB_PORT/"; then say "the face (Vite) :$WEB_PORT" "already answers — kept (ours)"
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
claim server "$PORT" "the server"; sc=$?
[ "$sc" = 2 ] && exit 1
if [ "$sc" = 0 ] && up "$URL/api/health" && { [ "$MODE" = "dev" ] || face_up "$URL"; }; then
  say "the server :$PORT" "already answers and serves the face — kept (ours)"
elif [ "$sc" = 0 ]; then
  say "the server :$PORT" "ours, but not serving the face — lower it: apps/bilskirnir/start.sh --stop"; exit 1
else
  spawn server "$APP/server" npx tsx --env-file=../.env src/index.ts
  wait_for "up $URL/api/health" 40 && say "the server :$PORT" "raised" || { say "the server :$PORT" "FAILED — see data/run/server.log"; exit 1; }
  if [ "$MODE" != "dev" ] && ! wait_for "face_up $URL" 10; then
    say "the server :$PORT" "answers but GET / is not the face — see data/run/server.log and web/dist"; exit 1
  fi
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
DEBUG=(); _dp="${BILSKIRNIR_DEBUG_PORT:-${YMIR_DEVTOOLS_PORT:-}}"; [ -n "$_dp" ] && DEBUG=(--remote-debugging-port="$_dp")
BILSKIRNIR_URL="$OPEN_URL" spawn window "$APP" "$ELECTRON" "${DEBUG[@]}" "$APP/electron"
sleep 2
window_up && say "the window" "open ($OPEN_URL)" || say "the window" "did not stay open — see data/run/window.log"
say "lower it" "apps/bilskirnir/start.sh --stop"

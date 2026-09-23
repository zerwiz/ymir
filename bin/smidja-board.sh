#!/usr/bin/env bash
# smidja-board.sh — Smíðja's board, by one name.
#
# The visualizer can live in two very different trees: a clone's
# `apps/smidja-factory/apps/visualizer`, or the `@zerwiz/smidja-factory` package
# a user got from npm. Its database lives in the HOME (`$YMIR_HOME/smidja/smidja.db`),
# not in either tree. This door resolves all three so the operator never has to.
#
#   smidja-board.sh build     # install deps and build the UI (./dist)
#   smidja-board.sh start     # raise the API + UI, detached, ready to answer
#   smidja-board.sh stop
#   smidja-board.sh status
#   smidja-board.sh --version | --help
#
# The operator's door is `ymir smidja [build|start|stop|status]` — this is what
# that door runs.
#
# Exit: 0 ok, 1 error, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# bun installs to ~/.bun/bin and is often absent from a non-login PATH; adopt it
# once so the board's build/run steps are not refused on a machine that HAS bun.
if ! command -v bun >/dev/null 2>&1 && [ -x "$HOME/.bun/bin/bun" ]; then
  PATH="$HOME/.bun/bin:$PATH"; export PATH
fi

# The operator's home: env -> the recorded choice -> the ONE documented default
# (Rule 07). No literal here — a literal would win over the resolver below and
# pin the machine to a dead path.
# shellcheck source=bin/hoard-lib.sh
. "$SCRIPT_DIR/hoard-lib.sh"
ymir_home_root YMIR_HOME
hoard_state_dir STATE
# shellcheck source=bin/smidja-lib.sh
. "$SCRIPT_DIR/smidja-lib.sh"

PORT="${SMIDJA_VIZ_API_PORT:-8437}"
PID_FILE="$STATE/smidja-viz-api.pid"
LOG_FILE="$STATE/smidja-viz-api.log"

# The database follows the HOME; SMIDJA_DB overrides. A tree-local copy is the
# last resort, for a checkout that keeps its own.
SMIDJA_DB_PATH="${SMIDJA_DB:-}"
if [ -z "$SMIDJA_DB_PATH" ]; then
  for _db in "$YMIR_HOME/smidja/smidja.db" "$ROOT/apps/smidja/smidja_data/smidja.db"; do
    [ -f "$_db" ] && { SMIDJA_DB_PATH="$_db"; break; }
  done
fi

viz_dir() {  # <result-var>
  local result_var=${1-} v
  [ -n "$result_var" ] || return 2
  if smidja_visualizer_dir v; then printf -v "$result_var" '%s' "$v"; return 0; fi
  printf -v "$result_var" '%s' ""; return 1
}

alive() { [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; }

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="$1"

VIZ=""
if ! viz_dir VIZ; then
  printf 'error: the visualizer is not installed in this tree\n'
  printf 'help: npm i -g @zerwiz/ymir (the smithy arrives as @zerwiz/smidja-factory)\n'
  exit 1
fi

case "$ACTION" in
  build)
    if ! command -v bun >/dev/null 2>&1; then
      printf 'error: bun is needed to build the UI\nhelp: bin/prereq-ensure.sh bun\n' >&2; exit 1
    fi
    printf 'visualizer_build[1]{step,state}:\n'
    if [ ! -d "$VIZ/node_modules" ]; then
      if (cd "$VIZ" && bun install >/dev/null 2>&1); then printf '  "deps","installed"\n'
      else printf '  "deps","FAILED — (cd %s && bun install)"\n' "$VIZ" >&2; exit 1; fi
    else printf '  "deps","present"\n'; fi
    if (cd "$VIZ" && bun run build >/dev/null 2>&1) || (cd "$VIZ" && bunx vite build >/dev/null 2>&1); then
      printf '  "ui","%s/dist"\n' "$VIZ"
    else
      printf 'error: the UI build failed\nhelp: (cd %s && bun run build)\n' "$VIZ" >&2; exit 1
    fi
    ;;
  start)
    command -v bun >/dev/null 2>&1 || { printf 'error: bun is needed to run the visualizer\nhelp: bin/prereq-ensure.sh bun\n' >&2; exit 1; }
    [ -n "$SMIDJA_DB_PATH" ] && [ -f "$SMIDJA_DB_PATH" ] || {
      printf 'error: no smidja.db found\nhelp: bin/smidja-bootstrap.sh (creates $YMIR_HOME/smidja/smidja.db)\n' >&2; exit 1; }
    [ -d "$VIZ/dist" ] || printf 'note: the UI is unbuilt — the API will answer and show no interface\nnote: mend it with: bin/ymir-visualizer.sh build\n' >&2
    if alive; then
      printf 'visualizer[1]{state,pid,url}:\n  "already running","%s","http://127.0.0.1:%s/"\n' "$(cat "$PID_FILE")" "$PORT"
      exit 0
    fi
    mkdir -p "$STATE"
    # ymir_detach PRINTS the pid it spawned (setsid/nohup is its business, not
    # ours); reading $! here would read a variable the helper already consumed.
    pid=""
    if command -v ymir_detach >/dev/null 2>&1; then
      pid="$(ymir_detach env CMD_DB="$SMIDJA_DB_PATH" PORT="$PORT" bun run "$VIZ/server/index.ts" 2>>"$LOG_FILE")"
    fi
    if [ -z "$pid" ]; then
      ( cd "$VIZ" && exec env CMD_DB="$SMIDJA_DB_PATH" PORT="$PORT" bun run server/index.ts ) >>"$LOG_FILE" 2>&1 &
      pid="$!"
    fi
    [ -n "$pid" ] && printf '%s\n' "$pid" >"$PID_FILE"
    for _i in $(seq 1 20); do
      curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$PORT/api/health" 2>/dev/null && break
      sleep 0.5
    done
    if curl -s --max-time 2 "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1; then
      printf 'visualizer[1]{state,db,url}:\n  "up","%s","http://127.0.0.1:%s/"\n' "$SMIDJA_DB_PATH" "$PORT"
    else
      printf 'error: the visualizer did not answer on :%s\nhelp: see %s\n' "$PORT" "$LOG_FILE" >&2; exit 1
    fi
    ;;
  stop)
    if alive; then
      kill "$(cat "$PID_FILE")" 2>/dev/null; rm -f "$PID_FILE"
      printf 'visualizer[1]{state}:\n  "stopped"\n'
    else
      rm -f "$PID_FILE"
      printf 'visualizer[1]{state}:\n  "not running"\n'
    fi
    ;;
  status)
    local_db="${SMIDJA_DB_PATH:-none}"
    if alive && curl -s --max-time 2 "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1; then
      printf 'visualizer[3]{state,pid,db,url}:\n  "up","%s","%s","http://127.0.0.1:%s/"\n' "$(cat "$PID_FILE")" "$local_db" "$PORT"
    elif alive; then
      printf 'visualizer[2]{state,pid,note}:\n  "starting or wedged","%s","answers nothing on :%s — see %s"\n' "$(cat "$PID_FILE")" "$PORT" "$LOG_FILE"
      exit 1
    else
      printf 'visualizer[3]{state,tree,db,ui}:\n  "down","%s","%s","%s"\n' "$VIZ" "$local_db" "$([ -d "$VIZ/dist" ] && echo built || echo unbuilt)"
    fi
    ;;
  *) printf 'error: unknown action %s\nhelp: bin/smidja-board.sh [build|start|stop|status]\n' "$ACTION" >&2; exit 2 ;;
esac

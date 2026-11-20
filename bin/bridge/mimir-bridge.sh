#!/usr/bin/env bash
# mimir-bridge.sh — raise/lower the well bridge (Mimirsbrunn on :4602).
# The engram engine speaks CLI + MCP; this keeps its HTTP face alive so the gate
# API, `bin/records/mimir.sh`, and the session start can drink from the well.
#
# Usage: bin/bridge/mimir-bridge.sh [--start|--stop|--status] [--port N] [--foreground]
#
# TWO DOORS, ONE WELL (RULES/25, RULES/39). Where the engine can be imported, this
# box SERIES it: the bridge is local. Where it cannot — a `hand` on Android/Termux,
# where engram's native pieces have no build — the same command raises the DOOR
# (bin/records/well-door.sh) to the heart's well, so `--start` is not a command that
# works on one role and fails on another. `--status` names which of the two answered.
#        bin/bridge/mimir-bridge.sh --foreground  # stay in the foreground (a systemd unit
#                                          # supervises this process directly — no self-daemon)
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "${ROOT:-}/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/hoard-lib.sh"; do
    [ -n "$_yc" ] && [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

# --- portability shim: bin/fleet/ymir-platform.sh --------------------------------
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  for _ymir_c in "$(git rev-parse --show-toplevel 2>/dev/null)/bin/fleet/ymir-platform.sh"                  "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/fleet/ymir-platform.sh"; do
    [ -n "$_ymir_c" ] && [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_c
fi

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$_yr/../vault/hoard-lib.sh" "$_yr/../../vault/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
BRIDGE="$ROOT/bin/bridge/mimir-bridge.py"
# The well is ONE memory and it lives in the hoard — always. An explicit
# ENGRAM_DB is the operator's escape hatch; without it the hoard decides.
if [ -n "${ENGRAM_DB:-}" ]; then
  DB="$ENGRAM_DB"
else
  hoard_memory_store DB
fi
PORT="${MIMIRSBRUNN_PORT:-4602}"
PID_FILE="${YMIR_STATE_DIR:-$YMIR_HOME/state}/mimir-bridge.pid"
LOG_FILE="${YMIR_STATE_DIR:-$YMIR_HOME/state}/mimir-bridge.log"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="start"
FOREGROUND=0
while [ $# -gt 0 ]; do
  case "$1" in
    --start|"") ACTION=start; shift ;;
    --stop) ACTION=stop; shift ;;
    --status) ACTION=status; shift ;;
    --foreground) FOREGROUND=1; shift ;;
    --port) PORT=${2-}; shift 2 ;;
    --python) ACTION=python; shift ;;
    *) printf 'error: unknown flag %s\nhelp: bin/bridge/mimir-bridge.sh [--start|--stop|--status|--foreground|--python]\n' "$1" >&2; exit 2 ;;
  esac
done

listening() { (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null && return 0 || return 1; }
bridge_pid_alive() { # 0 when THIS box owns the process on the port (not a borrowed door)
  [ -r "$PID_FILE" ] || return 1
  local pid; pid=$(tr -d '[:space:]' <"$PID_FILE" 2>/dev/null)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

# The ONE engram-interpreter resolver. engram needs Python >=3.12,<3.14, which the
# system python may not be: prefer a recorded interpreter, then a compatible one
# on PATH, and only then python3. `--python` prints it, so the well's log tool and
# the bridge itself never disagree about which python owns the store.
resolve_python() {
  local py="${YMIR_ENGRAM_PYTHON:-}"
  if [ -z "$py" ] && [ -r "${YMIR_ENGRAM_PY:-$HOME/.config/ymir/engram-python}" ]; then
    py="$(cat "${YMIR_ENGRAM_PY:-$HOME/.config/ymir/engram-python}" 2>/dev/null)"
  fi
  if [ -z "$py" ]; then
    for c in python3.12 python3.13; do command -v "$c" >/dev/null 2>&1 && { py="$c"; break; }; done
  fi
  [ -n "$py" ] || py=python3
  printf '%s' "$py"
}

case "$ACTION" in
  python)
    resolve_python; printf '\n'; exit 0 ;;
  status)
    if listening; then
      # Which door answered: a local engine, or the heart's well borrowed over ssh.
      # Naming it honestly is the difference between a green and a lie (2026-10-21).
      if bridge_pid_alive; then state="up (local)"; else state="up (door)"; fi
      printf 'well[1]{port,status}:\n  %s,"%s"\n' "$PORT" "$state"
    else printf 'well[1]{port,status}:\n  %s,"down"\n' "$PORT"; fi
    exit 0 ;;
  stop)
    stopped=0
    if [ -r "$PID_FILE" ]; then pid=$(tr -d '[:space:]' <"$PID_FILE"); if kill "$pid" 2>/dev/null; then stopped=1; fi; rm -f "$PID_FILE"; fi
    if listening; then ymir_kill_matching "bin/bridge/mimir-bridge.py" 2>/dev/null && stopped=1; fi
    # A borrowed door is closed by its own owner, or a hand leaves an ssh forward
    # standing for a well it no longer uses.
    if [ "$stopped" = 0 ] && [ -x "$ROOT/bin/records/well-door.sh" ] && listening; then
      "$ROOT/bin/records/well-door.sh" down >/dev/null 2>&1 && stopped=1
    fi
    if [ "$stopped" = 1 ]; then printf 'well: stopped\n'; else printf 'well: already stopped\n'; fi
    exit 0 ;;
esac

if listening; then
  pgrep -f "bin/bridge/mimir-bridge.py" >"$PID_FILE" 2>/dev/null || true
  printf 'well[1]{port,status}:\n  %s,"already up"\n' "$PORT"
  exit 0
fi
[ -e "$BRIDGE" ] || { printf 'error: bridge not found: %s\nhelp: expected bin/bridge/mimir-bridge.py\n' "$BRIDGE" >&2; exit 1; }
PY="$(resolve_python)"
if ! "$PY" -c "import engram" 2>/dev/null; then
  # PROBE, NEVER ASSUME (RULES/25). No local engine under this interpreter means this
  # box is a `hand` or a box that cannot build engram's native pieces — the well is then
  # the heart's, reached through the door. Same command, same answer, every role.
  DOOR="$ROOT/bin/records/well-door.sh"
  if [ -x "$DOOR" ]; then
    printf 'well: no local engine under %s — raising the door to the heart\n' "$PY" >&2
    if "$DOOR" up >/dev/null 2>&1 && listening; then
      printf 'well[1]{port,store,status}:\n  %s,"door","borrowed from the heart"\n' "$PORT"
      exit 0
    fi
    printf 'error: no local engine under %s, and the door to the heart did not answer\nhelp: bin/records/well-door.sh status\n' "$PY" >&2
    exit 1
  fi
  printf 'error: engram not installed for %s\nhelp: bin/engine/prereq-ensure.sh engram   (installs it into a compatible Python)\n' "$PY" >&2; exit 1
fi

mkdir -p "$YMIR_STATE_DIR" "$(dirname "$DB")"
if [ "$FOREGROUND" = 1 ]; then
  # A systemd unit owns this process: no self-daemon, no pid file, no port
  # poll — the bridge is the unit, and the unit's truth is the process's.
  exec env ENGRAM_DB="$DB" MIMIRSBRUNN_PORT="$PORT" "$PY" "$BRIDGE"
fi
ENGRAM_DB="$DB" MIMIRSBRUNN_PORT="$PORT" nohup "$PY" "$BRIDGE" >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
sleep 3
if listening; then
  printf 'well[1]{port,store,status}:\n  %s,"%s","started"\n' "$PORT" "${DB#"$ROOT"/}"
else
  printf 'error: well failed to start; see %s\n' "${LOG_FILE#"$ROOT"/}" >&2
  exit 1
fi

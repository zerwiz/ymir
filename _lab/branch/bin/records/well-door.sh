#!/usr/bin/env bash
# well-door.sh — the hand's door to the heart's well, raised over SSH.
#
# On a `hand` the well is NOT a local engine (bin/engine/ymir-install.sh says so
# plainly: "a hand reaches the heart's well as a door"). Android cannot build the
# engram native pieces, so the memory lives on the heart and the hand borrows it
# through an SSH local forward — the same road `bin/records/mimir.sh` and every
# MCP client already expect, on 127.0.0.1.
#
# Two doors, because the fleet has two faces and they are not the same age:
#
#   4602   the HTTP face (bin/bridge/mimir-bridge.py) — what mimir.sh speaks
#   8317   engram-mcp (HTTP/SSE) — what the MCP clients speak
#
# It PROBES both after raising and reports each honestly: a forward that is up
# while nothing listens behind it is a silent door, and saying "up" for it is the
# false green this house has been burned by twice (2026-10-21).
#
#   well-door.sh up        raise the forwards that are missing
#   well-door.sh down      close them
#   well-door.sh status    what each door answers, without changing anything
#
# Env: YMIR_HEART (ssh host alias, default zerwizserver) · WELL_HEART_HOST (what the
#      forward points at BEHIND the heart, default 127.0.0.1) · WELL_DOOR_PORTS.
#
# Exit: 0 every door answers · 1 a door is silent/absent · 2 usage.

set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _w in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$ROOT/bin/vault/hoard-lib.sh"; do
    [ -r "$_w" ] && { . "$_w"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _w
fi
HOME_DIR=""
if [ -n "${YMIR_HOME:-}" ]; then HOME_DIR="$YMIR_HOME"
elif command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root HOME_DIR
fi
[ -n "$HOME_DIR" ] || HOME_DIR="${HOME}"

STATE_DIR="${YMIR_STATE_DIR:-$HOME_DIR/state}"
DOOR_DIR="$STATE_DIR/well-door"
HEART="${YMIR_HEART:-zerwizserver}"
BEHIND="${WELL_HEART_HOST:-127.0.0.1}"
PORTS="${WELL_DOOR_PORTS:-4602 8317}"

probe() { # <port> -> 0 when something accepts a connection on 127.0.0.1:<port>
  { exec 3<>"/dev/tcp/127.0.0.1/$1"; } 2>/dev/null && { exec 3>&-; return 0; }
  return 1
}

heart_says() { # <port> -> the heart's own listener line, or nothing
  ssh -o BatchMode=yes -o ConnectTimeout=6 "$HEART" \
    "ss -ltn 2>/dev/null | awk '\$4 ~ /:$1\$/' | head -1" 2>/dev/null
}

door_status() { # <port> -> prints one TOON row; exit 0 when the heart answers THROUGH the door
  local p="$1" local_up=no heart_up=no heart_state state
  probe "$p" && local_up=yes
  heart_state="$(heart_says "$p")"
  [ -n "$heart_state" ] && heart_up=yes
  if [ "$heart_up" = yes ] && [ "$local_up" = yes ]; then state="answering"
  elif [ "$heart_up" = yes ]; then state="not raised (heart listens)"
  elif [ "$local_up" = yes ]; then state="forward up, but NOTHING behind it"
  else state="silent both ends"
  fi
  [ -n "$heart_state" ] || heart_state="nothing listening on the heart"
  printf '  "%s","%s","%s"\n' "$p" "$state" "$heart_state"
  [ "$state" = "answering" ]
}

cmd_status() {
  local rc=0 p
  printf 'well-door[%s]{port,here,heart}:\n' "$HEART"
  for p in $PORTS; do door_status "$p" || rc=1; done
  if [ "$rc" = 1 ]; then
    printf 'well-door: a door is silent — raise it: bin/records/well-door.sh up\n' >&2
  fi
  return "$rc"
}

cmd_up() {
  mkdir -p "$DOOR_DIR" 2>/dev/null || { printf 'well-door: cannot write %s\n' "$DOOR_DIR" >&2; return 1; }
  local p raised=0
  for p in $PORTS; do
    if probe "$p"; then continue; fi
    # A control socket, not a pattern: closing a door must name the door (the
    # pkill ward refuses to let anyone kill by pattern, and rightly).
    ssh -o BatchMode=yes -o ExitOnForwardFailure=yes -o ConnectTimeout=8 \
        -M -S "$DOOR_DIR/ctl-$p.sock" -N -f -L "127.0.0.1:$p:$BEHIND:$p" "$HEART" 2>/dev/null \
      && { printf '%s\n' "$p" >>"$DOOR_DIR/raised"; raised=$((raised+1)); } \
      || printf 'well-door: could not forward %s (ssh %s)\n' "$p" "$HEART" >&2
  done
  printf 'well-door: raised %s forward(s) to %s\n' "$raised" "$HEART"
  cmd_status
}

cmd_down() {
  local p
  for p in $PORTS; do
    if [ -S "$DOOR_DIR/ctl-$p.sock" ]; then
      ssh -S "$DOOR_DIR/ctl-$p.sock" -O exit "$HEART" 2>/dev/null
      rm -f "$DOOR_DIR/ctl-$p.sock" 2>/dev/null || true
    fi
    printf 'well-door: closed %s\n' "$p"
  done
  rm -f "$DOOR_DIR/raised" 2>/dev/null || true
  return 0
}

case "${1:-}" in
  up)     cmd_up ;;
  down)   cmd_down ;;
  status) cmd_status ;;
  -v|--version) printf '%s\n' "$VERSION" ;;
  -h|--help|"") sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) printf 'usage: well-door.sh up|down|status\n' >&2; exit 2 ;;
esac

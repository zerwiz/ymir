#!/usr/bin/env bash
# opendesign.sh — start / stop / status for OpenDesign (the design forge, Hnoss).
#
# The Allfather, 2026-10-02: *"stop open design"* … *"maestro are not open design. make stop and
# start script for open design"*.
#
# So this door is for **OpenDesign only**, and it is deliberately NOT confused with the video forge:
#   OpenDesign  the design studio, :7456        ← this door
#   Maestro     the video forge,      :7860       ← NOT this door (~/CodeP/start-maestro.sh)
#
# It also sweeps the **leaked stdio MCP children**: `open-design-mcp` is a stdio server, one per
# session that loaded the hnoss extension, and they outlive their session — three of them were up for
# 10+ hours on 2026-10-02 (71–72 MB each). Nothing calls a stdio server after the session ends, so
# stopping the design plane means stopping those too.
#
#   bin/pi/opendesign.sh start    # raise the studio, print where it is
#   bin/pi/opendesign.sh stop     # lower the studio and sweep its stdio children
#   bin/pi/opendesign.sh status        # what is up, on both the daemon and the children
set -uo pipefail

PORT="${OD_PORT:-7456}"
# The studio is a CONTAINER (`od:local`), not a process on this host - measured 2026-10-02:
# ss shows the socket with no owner, /proc finds nothing, lsof and fuser find nothing. My
# first draft of this door was written from the wrong belief and would have refused to stop it.
CONTAINER="${OD_CONTAINER:-open-design}"
HEALTH="${OD_HEALTH:-http://127.0.0.1:${PORT}/}"
BIN="${OD_BIN:-open-design-mcp}"                 # from mise's node bin; PATH is inherited
LOG="${OD_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir/opendesign.log}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/ymir"

children() { ps -eo pid,args --no-headers 2>/dev/null | grep -F "$BIN" | grep -v grep | awk '{print $1}'; }
say() { printf 'opendesign[1]{action,detail}:\n  "%s","%s"\n' "$1" "$2"; }

case "${1:-status}" in
  start)
    if curl -fsS -m 3 "$HEALTH" >/dev/null 2>&1; then
      say start "already up at http://127.0.0.1:${PORT}/ — nothing to do"
      exit 0
    fi
    if ! command -v docker >/dev/null 2>&1; then
      say start "no docker on this seat, and the studio is a container; raise it by hand"
      exit 1
    fi
    docker start "$CONTAINER" >/dev/null 2>&1 && say start "container $CONTAINER started" \
      || { say start "could not start container $CONTAINER"; exit 1; }
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      curl -fsS -m 3 "$HEALTH" >/dev/null 2>&1 && { say start "studio answering at http://127.0.0.1:${PORT}/"; exit 0; }
      sleep 1
    done
    say start "container started but :${PORT} has not answered within 10s — report, never pretend"
    exit 1
    ;;

  stop)
    n=0
    for p in $(children); do kill "$p" 2>/dev/null && n=$((n + 1)); done
    sleep 1
    for p in $(children); do kill -9 "$p" 2>/dev/null; done
    left=$(children | wc -l | tr -d ' ')
    say stop "swept ${n} stdio MCP child(ren); ${left} remain"
    if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
      docker stop "$CONTAINER" >/dev/null 2>&1 && say stop "container $CONTAINER stopped" \
        || say stop "could not stop container $CONTAINER"
    fi
    if curl -fsS -m 3 "$HEALTH" >/dev/null 2>&1; then
      say stop ":${PORT} is STILL answering — something else holds it; this door will not kill an unnamed one"
    else
      say stop ":${PORT} is silent — the design plane is down"
    fi
    printf '  the design plane is down; Maestro (the video forge, :7860) was NOT touched.\n'
    exit 0
    ;;

  status)
    kids=$(children | wc -l | tr -d ' ')
    if curl -fsS -m 3 "$HEALTH" >/dev/null 2>&1; then st="up"; else st="down"; fi
    cs="absent"
    command -v docker >/dev/null 2>&1 && cs="$(docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER" && echo running || echo stopped)"
    say status "studio :${PORT} ${st} · container ${cs} · stdio MCP children ${kids}"
    exit 0
    ;;

  *)
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac

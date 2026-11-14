#!/usr/bin/env bash
# voice-idle.sh — the voice engine lets the card go when nobody is on the line.
#
# WHY (plan 275 item 23, measured 2026-11-14 03:16): the streaming voice engine
# (`speech-to-speech serve`, raised by voice-door.sh as `ymir-voice-host.service`) sits on
# ~2.7 GiB of a 16 GiB card and never lets go. With the display and voxtype already there,
# nothing was left for the rail: it failed to load `qwen3.6-35b-a3b` (cudaMalloc of
# 1,184 MiB) and `apodex-1.0-mini` (3,314 MiB) — and every chat then had no road at all.
#
# So the engine idles out: after a call ends, and after a window with no session held, the
# unit is stopped and the card is free again. Raising it is unchanged (`voice-door.sh host`,
# Rödd's own start, the `start` verb) — this door only ever LOWERS, and only on evidence:
# the engine's own pool (`GET /v1/pool` → `{size, in_use}`) must say no session is in use.
#
#   voice-idle.sh status       is a call held, and how long the window is
#   voice-idle.sh check        exit 0 when a call IS held, 3 when the engine is idle
#   voice-idle.sh watch        the loop: stop the host after YMIR_VOICE_IDLE_SECONDS idle
#   voice-idle.sh reap         one pass of the same judgement (what `watch` does each tick)
#   voice-idle.sh --version
#
# Env:
#   YMIR_VOICE_PORT          the engine's port                (default 8890)
#   YMIR_VOICE_IDLE_SECONDS  a quiet window before it stops   (default 300; 0 disables)
#   YMIR_VOICE_HOST_UNIT     the unit to lower                 (default ymir-voice-host.service)
#
# Exit: 0 ok/held · 3 nothing to do (idle, or no engine) · 2 usage.
set -u
VERSION="1.0.0"
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; printf '%s' "$d")"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true

PORT="${YMIR_VOICE_PORT:-8890}"
IDLE_SECONDS="${YMIR_VOICE_IDLE_SECONDS:-300}"
UNIT="${YMIR_VOICE_HOST_UNIT:-ymir-voice-host.service}"
STATE_DIR="${YMIR_HOME:-$HOME}/hodd/state/voice"
LOG="$STATE_DIR/idle.log"

CMD="${1:-status}"; shift || true
while [ $# -gt 0 ]; do case "$1" in --seconds) IDLE_SECONDS=${2-}; shift 2 ;; *) shift ;; esac; done

say() { printf '%s\n' "$*"; }
log() { mkdir -p "$STATE_DIR" 2>/dev/null; printf '%s %s\n' "$(date -Is)" "$*" >>"$LOG" 2>/dev/null; }

unit_up() { systemctl --user is-active --quiet "$UNIT" 2>/dev/null; }

# The engine's OWN count of sessions: `{size, in_use, units:[{state, draining_for_s}]}` on
# /v1/pool (speech-to-speech v1.1.0). A connected client HOLDS a unit, so a call is never
# cut off by a quiet moment. A unit that has been `draining` for over a minute is NOT a
# call — a client that vanished mid-turn leaves exactly that state, and counting it forever
# would keep the card held no matter how long the room stayed empty (the same fault this
# door exists to remove, one level down).
pool() {
  curl -s --max-time 2 "http://127.0.0.1:$PORT/v1/pool" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit(2)
units = d.get("units") or []
if units:
    def holds(u):
        state = str(u.get("state") or "").lower()
        if state in ("", "idle"):
            return False
        # a unit still DRAINING is a call finishing; one draining for over a minute is a
        # client that vanished mid-turn, and counting it would hold the card forever
        if state == "draining":
            return float(u.get("draining_for_s") or 0) < 60
        return True
    held = sum(1 for u in units if holds(u))
else:
    held = int(d.get("in_use") or 0)
print("%d %d" % (int(d.get("size") or 0), held))'
}

# 0 = a call is held · 1 = the engine is idle · 2 = the engine does not answer
judge() {
  local size inuse
  read -r size inuse <<<"$(pool)" || return 2
  [ -n "${size:-}" ] || return 2
  [ "$inuse" -gt 0 ] && return 0
  return 1
}

case "$CMD" in
  check)
    judge; rc=$?
    [ "$rc" -eq 0 ] && { say "voice: a call is held"; exit 0; }
    [ "$rc" -eq 1 ] && { say "voice: idle (no session in use)"; exit 3; }
    say "voice: the engine does not answer on :$PORT"; exit 3 ;;
  status)
    st="down"; state="no engine"
    if unit_up; then
      st="up"
      judge; case $? in 0) state="a call is held" ;; 1) state="idle — it will let the card go" ;; 2) state="up, pool unreadable" ;; esac
    fi
    printf 'voice_idle[4]{unit,state,call,idle_seconds}:\n  "%s","%s","%s","%s"\n' "$UNIT" "$st" "$state" "$IDLE_SECONDS"
    exit 0 ;;
  reap|watch) ;;
  *) printf 'error: unknown command %s\nhelp: bin/voice/voice-idle.sh [status|check|watch|reap]\n' "$CMD" >&2; exit 2 ;;
esac

reap_once() {
  local idle_for=0
  [ "${IDLE_SECONDS:-0}" -gt 0 ] 2>/dev/null || { say "voice: idle-out disabled (YMIR_VOICE_IDLE_SECONDS=$IDLE_SECONDS)"; return 1; }
  unit_up || { return 1; }                       # nothing raised: nothing to lower
  judge && { say "voice: a call is held — the card stays"; return 1; }
  # One quiet reading is not a quiet window: the engine is given the whole window before it
  # is stopped, and a session that arrives in that window resets it.
  while [ "$idle_for" -lt "$IDLE_SECONDS" ]; do
    sleep 5; idle_for=$((idle_for+5))
    judge && { say "voice: a call started — the card stays"; log "call started at ${idle_for}s; not stopping"; return 1; }
    unit_up || { return 1; }
  done
  systemctl --user stop "$UNIT" 2>/dev/null || return 1
  say "voice: no call for ${IDLE_SECONDS}s — stopped $UNIT and let the card go"
  log "idle-out: stopped $UNIT after ${IDLE_SECONDS}s with no session in use"
  return 0
}

if [ "$CMD" = reap ]; then
  reap_once; exit $?
fi

# watch — the loop systemd keeps alive beside the engine. It never raises anything.
log "watch started (idle window ${IDLE_SECONDS}s, port $PORT)"
while :; do
  if ! unit_up; then log "the host unit is down; the watcher exits"; exit 0; fi
  if reap_once; then exit 0; fi
  sleep 5
done

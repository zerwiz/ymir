#!/usr/bin/env bash
# arm-send.sh — the wire between the fleet's arm holders (plan 253 phase 3 "the wire"; plan 234; RULES/49).
#
#   bin/fleet/arm-send.sh <machine> "<one line>"     hand the arm holder on that machine a signed line
#   bin/fleet/arm-send.sh --who                      who holds the arm on every machine
#
# WHY. Every machine has an arm holder (the session that holds its Gná lock) and the same door to reach it,
# bin/voice/rodd-arm.sh `tell`, which drops a `signal` wake into the queue that holder reads. But that door only
# reached the holder on its own machine: "a remote route must be nudged on its own host" (plan 253, measured
# 2026-11-11), so heimdall's helm could not ask nidavellir's anything without a human paste. This carries `tell` over
# the fleet's own roads (hodd/data/fleet.json: user and tailnet name), signed with the sending seat's name, and puts
# the way back in the line, so the receiver can answer with one command.
#
# The law it keeps (RULES/49, plan 234): a message is not delivered until the receiver speaks. A `tell` that lands
# says "handed", never "done"; the answer is what proves it.
set -u
ROOT="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh"; ymir_home_root HOME_DIR   # the one resolver: env, then recorded, then the default
REG="$HOME_DIR/hodd/data/fleet.json"
me="$(hostname -s)"
seat="$(sed -n 's/^primary=//p' "$HOME/.pi/agent/extensions/.ymir-seat" 2>/dev/null | head -1)"
seat="${YMIR_SEAT_NAME:-${seat:-$me}}"

road() {  # <machine> → user@tailnet, or nothing
  python3 - "$REG" "$1" <<'PY'
import json, sys
h = (json.load(open(sys.argv[1])).get("hosts") or {}).get(sys.argv[2]) or {}
if h.get("user") and h.get("tailnet"): print(f"{h['user']}@{h['tailnet']}")
PY
}
door() {  # <machine> <rodd-arm verb> [args…] — here, or on that machine over its road
  local host="$1"; shift
  if [ "$host" = "$me" ]; then bash "$ROOT/bin/voice/rodd-arm.sh" "$@"; return; fi
  local r; r="$(road "$host")"
  [ -n "$r" ] || { printf 'arm-send: no road to %s in %s\n' "$host" "$REG" >&2; return 2; }
  local q=""; for a in "$@"; do q="$q $(printf '%q' "$a")"; done
  ssh -o BatchMode=yes -o ConnectTimeout=6 "$r" \
    "bash -lc 'd=\${YMIR_RUNTIME_DIR:-\$HOME/ymir-runtime}; [ -f \$d/bin/voice/rodd-arm.sh ] || d=\$HOME/ymir; cd \$d && bash bin/voice/rodd-arm.sh$(printf '%s' "$q" | sed "s/'/'\\\\''/g")'"
}

case "${1:-}" in
  --who)
    for h in $(python3 -c "import json;print(' '.join(k for k,v in (json.load(open('$REG')).get('hosts') or {}).items() if v.get('user') and v.get('tailnet')))"); do
      out="$(timeout 15 bash -c "$(declare -f road door); REG='$REG' me='$me' ROOT='$ROOT'; door '$h' who" 2>&1)"; rc=$?
      case "$rc" in 0) printf '%s\theld\t%s\n' "$h" "$(printf '%s' "$out" | sed -n '2p' | cut -d, -f1-2)" ;;
                     3) printf '%s\tnobody holds the arm\n' "$h" ;;
                     *) printf '%s\tno answer\t%s\n' "$h" "$(printf '%s' "$out" | tail -1 | cut -c1-80)" ;; esac
    done ;;
  ""|-h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
  *)
    host="$1"; shift; text="$*"
    [ -n "$text" ] || { echo "arm-send: give the line to send" >&2; exit 2; }
    # the way back, written so it works on a machine that does not carry this script yet
    back="answer with one command: ssh $(road "$me" || true) 'cd ~/ymir-runtime && bash bin/voice/rodd-arm.sh tell --from YOUR-SEAT \"<your answer>\"' (or bin/fleet/arm-send.sh $me \"<your answer>\")"
    door "$host" tell --from "$seat ($me)" "$text — $back"
    rc=$?
    case "$rc" in
      0) printf 'arm-send\thanded\t%s\tto the arm holder on %s; it is delivered when they answer (RULES/49)\n' "$seat" "$host" ;;
      3) printf 'arm-send\tREFUSED\tnobody holds the arm on %s — nothing was handed\n' "$host" ;;
      *) printf 'arm-send\tFAILED\t%s did not take it (exit %s)\n' "$host" "$rc" ;;
    esac
    exit "$rc" ;;
esac

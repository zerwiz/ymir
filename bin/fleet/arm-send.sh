#!/usr/bin/env bash
# arm-send.sh — the wire between the fleet's arm holders (plan 253 phase 3 "the wire"; plan 234; RULES/49).
#
#   bin/fleet/arm-send.sh <machine> "<one line>"     hand the arm holder on that machine a signed line
#   bin/fleet/arm-send.sh --who                      who holds the arm on every machine
#   bin/fleet/arm-send.sh --pending                  tells still inside their deadline
#   bin/fleet/arm-send.sh --expired [--notify]       tells whose deadline passed unacked (the escalation)
#   bin/fleet/arm-send.sh --ack <tell-id>            the receiver marks a tell answered
#
# WHY. Every machine has an arm holder (the session that holds its Gná lock) and the same door to reach it,
# bin/voice/rodd-arm.sh `tell`, which drops a `signal` wake into the queue that holder reads. But that door only
# reached the holder on its own machine: "a remote route must be nudged on its own host" (plan 253, measured
# 2026-11-11), so one machine's helm could not ask another's anything without a human paste. This carries `tell` over
# the fleet's own roads (hodd/data/fleet.json: user and tailnet name), signed with the sending seat's name, and puts
# the way back in the line, so the receiver can answer with one command.
#
# THE LAW IT KEEPS (RULES/49, plan 234): a message is not delivered until the receiver speaks. A `tell` that lands
# says "handed", never "done"; the answer is what proves it.
#
# AND A TELL CARRIES A DEADLINE (plan 310 §4). A question with no end waits for ever, and an arm that never answered
# looks exactly like an arm that answered late — which is how the heart's tell sat unanswered all morning while its
# arm read `held`. So every tell is stamped with the instant it expires, the stamp travels INSIDE the line (the
# holder must see it, not a ledger they never read), and every tell is written to a ledger this door owns:
#
#   <state>/arm-tells.tsv     id · sent · to · from · deadline · acked · text
#
# `--expired` reports the unacked tells past their deadline — the escalation — and `--ack <id>` is how the receiver
# closes one. The ledger is the door's own record (a tell is not a wake queue line and never rewrites one).
set -u
ROOT="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh"; ymir_home_root HOME_DIR   # the one resolver: env, then recorded, then the default
hoard_state_dir TELL_STATE 2>/dev/null || TELL_STATE="${YMIR_STATE_DIR:-$HOME_DIR/state}"
REG="$HOME_DIR/hodd/data/fleet.json"
LEDGER="$TELL_STATE/arm-tells.tsv"
# ONE number: how long a tell may stand unanswered before it escalates (plan 310 §7.2 keeps the ruling).
TELL_DEADLINE="${YMIR_TELL_DEADLINE:-1800}"
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

stamp() {  # <epoch> — the instant as a person reads it, in this machine's own zone
  date -d "@$1" '+%Y-%m-%d %H:%M %Z' 2>/dev/null || printf '%s' "$1"
}

ledger_add() {  # <id> <sent> <to> <from> <deadline> <text>
  mkdir -p "$TELL_STATE" 2>/dev/null || return 1
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "-" \
    "$(printf '%s' "$6" | tr '\t\r\n' '   ')" >>"$LEDGER"
}

ledger_ack() {  # <id> — mark answered, in place, atomically
  local id="$1" tmp="$LEDGER.$$" line rid sent to from deadline acked text found=0
  [ -r "$LEDGER" ] || return 2
  while IFS= read -r line || [ -n "$line" ]; do
    IFS=$'\t' read -r rid sent to from deadline acked text <<<"$line"
    if [ "$rid" = "$id" ]; then
      found=1
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$rid" "$sent" "$to" "$from" "$deadline" "$(date +%s)" "$text"
    else
      printf '%s\n' "$line"
    fi
  done <"$LEDGER" >"$tmp"
  [ "$found" = 1 ] || { rm -f "$tmp"; return 2; }
  mv "$tmp" "$LEDGER"
}

ledger_report() {  # <expired|pending> [--notify]
  local mode="$1" notify="${2:-}" now rows=0 line id sent to from deadline acked text state left
  now="$(date +%s)"
  printf 'arm-tells[1]{verdict,mode,ledger,now,deadline_default_s}:\n'
  printf '  "report","%s","%s","%s","%s"\n' "$mode" "$LEDGER" "$now" "$TELL_DEADLINE"
  printf 'tells{state,id,to,from,sent,deadline,left_s,text}:\n'
  if [ -r "$LEDGER" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      [ -n "$line" ] || continue
      IFS=$'\t' read -r id sent to from deadline acked text <<<"$line"
      [ "$acked" = "-" ] || continue
      left=$(( deadline - now ))
      if [ "$mode" = expired ]; then
        [ "$left" -lt 0 ] || continue
        state=EXPIRED
      else
        [ "$left" -ge 0 ] || continue
        state=pending
      fi
      rows=$((rows + 1))
      printf '  "%s","%s","%s","%s","%s","%s","%s","%s"\n' \
        "$state" "$id" "$to" "$from" "$(stamp "$sent")" "$(stamp "$deadline")" "$left" \
        "$(printf '%s' "$text" | cut -c1-110)"
    done <"$LEDGER"
  fi
  if [ "$rows" = 0 ]; then
    printf '  "none","-","-","-","-","-","-","nothing to report"\n'
  else
    printf 'summary: %s tell(s) %s\n' "$rows" \
      "$([ "$mode" = expired ] && printf 'past their deadline and never answered — ESCALATE to the Allfather' || printf 'still inside their deadline')"
  fi
  # The escalation is the report itself; --notify also raises it on the desk he reads.
  if [ "$mode" = expired ] && [ "$rows" -gt 0 ] && [ "$notify" = --notify ]; then
    local send="$ROOT/bin/notify/send.sh"
    if [ -x "$send" ]; then
      bash "$send" --key "arm-send:expired" \
        "arm-send: $rows tell(s) went past their deadline unanswered — bin/fleet/arm-send.sh --expired" \
        >/dev/null 2>&1 || printf 'arm-send: the notify door did not take the escalation\n' >&2
    else
      printf 'arm-send: no notify door on this tree — the report above IS the escalation\n' >&2
    fi
  fi
  [ "$mode" = expired ] && [ "$rows" -gt 0 ] && return 1
  return 0
}

case "${1:-}" in
  --who)
    for h in $(python3 -c "import json;print(' '.join(k for k,v in (json.load(open('$REG')).get('hosts') or {}).items() if v.get('user') and v.get('tailnet')))"); do
      out="$(timeout 15 bash -c "$(declare -f road door); REG='$REG' me='$me' ROOT='$ROOT'; door '$h' who" 2>&1)"; rc=$?
      case "$rc" in 0) printf '%s\theld\t%s\n' "$h" "$(printf '%s' "$out" | sed -n '2p' | cut -d, -f1-2)" ;;
                     3) printf '%s\tnobody holds the arm\n' "$h" ;;
                     *) printf '%s\tno answer\t%s\n' "$h" "$(printf '%s' "$out" | tail -1 | cut -c1-80)" ;; esac
    done ;;
  --expired) shift; ledger_report expired "${1:-}" ;;
  --pending) shift; ledger_report pending "${1:-}" ;;
  --ack) shift
    id="${1:-}"; [ -n "$id" ] || { echo "arm-send: --ack needs a tell id (arm-send.sh --pending lists them)" >&2; exit 2; }
    if ledger_ack "$id"; then printf 'arm-send\ttell\t%s\tanswered — it will not escalate\n' "$id"
    else printf 'arm-send\ttell\t%s\tNOT found in %s — nothing was marked\n' "$id" "$LEDGER" >&2; exit 3; fi ;;
  ""|-h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
  *)
    host="$1"; shift; text="$*"
    [ -n "$text" ] || { echo "arm-send: give the line to send" >&2; exit 2; }
    now="$(date +%s)"
    deadline=$(( now + TELL_DEADLINE ))
    tell_id="t${now}-$(printf '%04x' "$(( (now + $$) % 65536 ))")"
    # the way back, written so it works on a machine that does not carry this script yet
    back="answer with one command: ssh $(road "$me" || true) 'cd ~/ymir-runtime && bash bin/voice/rodd-arm.sh tell --from YOUR-SEAT \"<your answer>\"' (or bin/fleet/arm-send.sh $me \"<your answer>\")"
    # THE DEADLINE TRAVELS IN THE LINE: the holder reads the wake, not this ledger.
    door "$host" tell --from "$seat ($me)" "$text — $back — tell $tell_id, DEADLINE $(stamp "$deadline") (unacked tells escalate to the Allfather: bin/fleet/arm-send.sh --ack $tell_id answers it)"
    rc=$?
    case "$rc" in
      0) ledger_add "$tell_id" "$now" "$host" "$seat ($me)" "$deadline" "$text"
         printf 'arm-send\thanded\t%s\tto the arm holder on %s; it is delivered when they answer (RULES/49)\n' "$seat" "$host"
         printf 'arm-send-tell[1]{tell,deadline,expires_in_s,escalate_with,answer_with}:\n'
         printf '  "%s","%s","%s","arm-send.sh --expired","arm-send.sh --ack %s"\n' \
           "$tell_id" "$(stamp "$deadline")" "$(( deadline - now ))" "$tell_id" ;;
      3) printf 'arm-send\tREFUSED\tnobody holds the arm on %s — nothing was handed, and no deadline was written\n' "$host" ;;
      *) printf 'arm-send\tFAILED\t%s did not take it (exit %s)\n' "$host" "$rc" ;;
    esac
    exit "$rc" ;;
esac

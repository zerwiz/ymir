#!/usr/bin/env bash
# eindri-seat.sh — seat a worker and PROVE it, in one move.
#
# The lesson from firstmate (bin/fm-spawn.sh + fm-send.sh + fm-peek.sh): a spawn
# is not a seat until the brief is delivered AND the agent has been read. Ymir
# had ported only the launcher, so a seat could be reported while the worker sat
# idle — "sent but never started". This is the missing half, in our idiom.
#
#   bin/eindri-seat.sh <name> --role <role> [--model <model>] -- "<brief>"
#
# It seats through bin/herdr-run.sh (the house door, so the model->harness rule
# and the pane bookkeeping stay in one place), waits for the pane to settle,
# reads it, and reports what the agent ACTUALLY is:
#
#   state: working  — it has begun (exit 0)
#   state: idle     — seated but nothing ran (exit 3: a seat, not an errand)
#   state: error    — the pane shows a refusal (the 403/1010 class) (exit 1)
#
# Nothing is claimed that the pane does not show.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SETTLE="${YMIR_SEAT_SETTLE:-35}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

NAME="${1:-}"; shift || true
[ -n "$NAME" ] || { printf 'error: a name is required\nhelp: bin/eindri-seat.sh <name> --role <role> -- "<brief>"\n' >&2; exit 2; }

# hand the rest to the house door, which owns the harness rule and the pane log
SEAT_OUT="$("$SCRIPT_DIR/herdr-run.sh" eindri "$NAME" "$@" 2>&1)"
RC=$?
printf '%s\n' "$SEAT_OUT"

# The pane id is the door's own answer; without it there is nothing to read.
# The door answers with the TAB; the pane must be resolved from it (its row
# carries the eindri's name in the pane field, which is how I once read a name
# as a pane and reported an empty tail as an idle agent).
TAB="$(printf '%s\n' "$SEAT_OUT" | sed -n 's/.*","\(w[0-9]*:t[0-9A-Za-z]*\)","[a-z]*".*/\1/p' | head -1)"
PANE=""
if [ -n "$TAB" ] && [ -x "${HERDR_BIN_PATH:-}" ]; then
  PANE="$("${HERDR_BIN_PATH}" pane list 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    raise SystemExit
tab=sys.argv[1] if len(sys.argv)>1 else ''
for p in d.get('result',{}).get('panes',[]) or []:
    if p.get('tab_id')==tab and p.get('agent'):
        print(p.get('pane_id','')); break
" "$TAB")"
fi
if [ -z "$PANE" ]; then
  # herdr absent or the door refused: report what it said, claim nothing more.
  printf 'eindri[1]{name,state,detail}:\n  "%s","unseated","the door did not return a pane"\n' "$NAME"
  exit "$([ "$RC" = 0 ] && echo 3 || echo 1)"
fi

sleep "$SETTLE"
TAIL="$("${HERDR_BIN_PATH:-herdr}" pane read "$PANE" 2>/dev/null | tail -25)"

STATE="idle"; WHY="seated, but the pane shows no work yet"
case "$TAIL" in
  *"Error: 403"*|*"error code: 1010"*|*"Access denied"*)
    STATE="blocked"; WHY="the provider refused the client (403/1010 class) — see the pane" ;;
  *working*|*"esc interrupt"*|*"thinking"*|*"✻"*|*"▣"*)
    STATE="working"; WHY="the agent has begun" ;;
esac

printf 'eindri[1]{name,pane,state,detail}:\n  "%s","%s","%s","%s"\n' "$NAME" "$PANE" "$STATE" "$WHY"
printf 'pane_tail[1]{last_lines}:\n  "%s"\n' "$(printf '%s' "$TAIL" | tail -3 | tr '\n' '~' | sed 's/"/\\"/g' | cut -c1-200)"

case "$STATE" in
  working) exit 0 ;;
  blocked) exit 1 ;;
  *) exit 3 ;;
esac

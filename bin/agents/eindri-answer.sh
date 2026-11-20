#!/usr/bin/env bash
# eindri-answer.sh — answer a worker's question in ONE act: speak it into the pane, record it, close it.
#
# WHY (plan 339.3, 2026-11-20): ten errand questions sat in the home with no answer while the hall
# showed their workers as idle. The arm now wakes the helm on a question unanswered for 15 minutes and
# reaches the operator after an hour (src/ymir_runtime/watch.py, question_wake). An answer must
# therefore be something the arm can SEE: this door is that act.
#
#   bin/agents/eindri-answer.sh <errand-id> "<the answer>"          # speak, record, close
#   bin/agents/eindri-answer.sh <errand-id> --record-only "<text>"  # answered another way: record and close
#   bin/agents/eindri-answer.sh --list                              # the open questions, oldest first
#
# It does, in order:
#   1. speaks the answer into the worker's pane through bin/agents/eindri-send.sh (the pane is read from
#      state/<id>.meta: seat_pane, else window). A send that fails stops here: the question stays open.
#   2. appends `answer: <stamp> — <text>` to state/eindri-questions/<id>.md;
#   3. moves the file to state/eindri-questions/answered/ (a second answer keeps both, by time).
#
# --from "<who>" names the sender, as eindri-send.sh does (default: "the helm").
#
# Exit: 0 answered · 1 the send or the record failed (the question stays open) · 2 usage · 3 no such question.
set -u
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ] && [ -r "$SCRIPT_DIR/../vault/hoard-lib.sh" ]; then
  . "$SCRIPT_DIR/../vault/hoard-lib.sh"
  YMIR_HOARD_LIB_LOADED=1
fi
hoard_state_dir YMIR_STATE_DIR
. "$SCRIPT_DIR/eindri-wake-lib.sh"
eindri_helm_state STATE "$YMIR_STATE_DIR"
QDIR="$STATE/eindri-questions"
SEND="${EINDRI_ANSWER_SEND:-$SCRIPT_DIR/eindri-send.sh}"

usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; }

FROM="the helm"; RECORD_ONLY=0; ID=""; TEXT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --list)
      found=0
      while IFS= read -r q; do
        [ -n "$q" ] || continue
        found=1
        age=$(( ( $(date +%s) - $(date -r "$q" +%s) ) / 60 ))
        printf '%s · %s min · %s\n' "$(basename "$q" .md)" "$age" \
          "$(grep -m1 -v '^[[:space:]]*$' "$q" | sed 's/^#* *//' | cut -c1-100)"
      done < <(ls -tr "$QDIR"/*.md 2>/dev/null)
      [ "$found" = 1 ] || printf 'no open questions in %s\n' "$QDIR"
      exit 0 ;;
    --from) FROM="${2-}"; shift 2 ;;
    --record-only) RECORD_ONLY=1; shift ;;
    -*) printf 'error: unknown flag %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *)
      if [ -z "$ID" ]; then ID=$1
      elif [ -z "$TEXT" ]; then TEXT=$1
      else printf 'error: too many arguments\n' >&2; exit 2
      fi
      shift ;;
  esac
done
[ -n "$ID" ] && [ -n "$TEXT" ] || { usage >&2; exit 2; }
Q="$QDIR/$ID.md"
[ -f "$Q" ] || { printf 'error: no open question from %s (%s)\nhelp: bin/agents/eindri-answer.sh --list\n' "$ID" "$Q" >&2; exit 3; }

if [ "$RECORD_ONLY" = 0 ]; then
  pane="$(sed -n 's/^seat_pane=//p' "$STATE/$ID.meta" 2>/dev/null | tail -1)"
  [ -n "$pane" ] || pane="$(sed -n 's/^window=//p' "$STATE/$ID.meta" 2>/dev/null | tail -1)"
  if [ -z "$pane" ]; then
    printf 'error: no pane is recorded for %s in %s\nhelp: answer it in the pane yourself, then --record-only\n' "$ID" "$STATE/$ID.meta" >&2
    exit 1
  fi
  if ! "$SEND" --from "$FROM" "$pane" "Answer to your question: $TEXT"; then
    printf 'error: the answer did not reach %s in %s — the question stays open\n' "$ID" "$pane" >&2
    exit 1
  fi
fi

stamp="$(sol_line 2>/dev/null || date '+%Y-%m-%d %H:%M %Z')"
printf '\nanswer: %s — %s (from %s)\n' "$stamp" "$TEXT" "$FROM" >>"$Q" || { printf 'error: cannot write %s\n' "$Q" >&2; exit 1; }
mkdir -p "$QDIR/answered"
dest="$QDIR/answered/$ID.md"
[ -e "$dest" ] && dest="$QDIR/answered/$ID.$(date -u +%Y%m%dT%H%M%SZ).md"
mv "$Q" "$dest" || { printf 'error: answered, but cannot move %s to %s\n' "$Q" "$dest" >&2; exit 1; }
printf 'eindri-answer[1]{errand,answered,file}:\n  "%s","%s","%s"\n' "$ID" "$([ "$RECORD_ONLY" = 1 ] && echo recorded || echo spoken)" "$dest"

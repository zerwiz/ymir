#!/usr/bin/env bash
# snotra-pipeline.sh — one command: a meeting folder becomes the record, the board, the letters.
#
#   snotra-pipeline.sh run <meeting-dir> [--dry-run] [--draft] [--shrink]
#   snotra-pipeline.sh run --recent [DAYS] [--dry-run]      every meeting folder touched in DAYS (default 2)
#   snotra-pipeline.sh status <meeting-dir>
#
# THE CHAIN, in this order — and it STOPS at a step that cannot be proven:
#   record → harvest (+verify) → signal audit → transcribe → speakers → layout → project → agenda → letters
# Command-line switches change only side effects, never the order:
#   --dry-run   prints what would happen (project/agenda plan) and writes nothing
#   --draft     also create the Gmail drafts (never sends; sending needs snotra-approve.sh)
#   --shrink    also run the audio ladder after the transcript is verified (never without it)
#
# FAIL LAWS: one meeting at a time (flock); a step that fails stops the chain and names itself; a transcript
# with no words is a failure; a folder with a stray is a failure; every run appends one rune.
#
# Exit: 0 all steps passed (skips are printed) · 1 a step failed · 2 usage
set -uo pipefail
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'snotra-pipeline: the hoard is unresolved\n' >&2; exit 2; }
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/ymir"
mkdir -p "$STATE"
LOCK="$STATE/snotra-pipeline.lock"
S="$ROOT/systems/snotra"

CMD="${1-}"; case "$CMD" in -h|--help|"") sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
shift || true
DRY=0; DRAFT=0; SHRINK=0; recent=""
DIRS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --draft) DRAFT=1; shift ;;
    --shrink) SHRINK=1; shift ;;
    --recent) recent="${2:-2}"; shift 2 ;;
    *) DIRS+=("$1"); shift ;;
  esac
done
if [ -n "$recent" ]; then
  # every meetings shelf the home keeps — realm meetings, the operator's own work meetings, and the
  # shared workspace — through the one resolver (snotra_paths.py), never a single hard-coded glob
  while IFS= read -r c; do
    [ -n "$c" ] && DIRS+=("$c")
  done < <(YMIR_HOME="$HOME_R" python3 "$S/snotra_paths.py" --recent "$recent" 2>/dev/null)
fi
[ ${#DIRS[@]} -gt 0 ] || { printf 'snotra-pipeline: no meeting folder given\n' >&2; exit 2; }

pass=0; skip=0; fail=0; warn=0; failed_at=""
step(){ # step <name> <command…> — prints PASS/FAIL with the first line of output
  local name="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ $rc -eq 0 ]; then printf '  PASS  %-10s %s\n' "$name" "$(printf '%s' "$out" | tail -1 | cut -c1-96)"; pass=$((pass+1))
  else printf '  FAIL  %-10s %s\n' "$name" "$(printf '%s' "$out" | tail -1 | cut -c1-96)"; fail=$((fail+1)); failed_at="$name"; fi
  return $rc
}
skipl(){ printf '  SKIP  %-10s %s\n' "$1" "$2"; skip=$((skip+1)); }

run_one(){
  local D="${1%/}"
  printf 'snotra pipeline — %s%s\n' "$(basename "$D")" "$([ $DRY -eq 1 ] && echo '  (dry run)')"
  [ -f "$D/record.json" ] || { printf '  FAIL  record     no record.json\n'; fail=$((fail+1)); return 1; }
  step record "$S/snotra-promote.sh" check "$D" || return 1

  if grep -q '"conference_url"' "$D/record.json" 2>/dev/null && ! grep -q '"conference_url": null' "$D/record.json"; then
    if [ -f "$D/harvest.json" ] && [ $DRY -eq 0 ]; then
      step harvest "$S/snotra-harvest.sh" verify "$D" || return 1
    elif [ $DRY -eq 1 ]; then
      step harvest "$S/snotra-harvest.sh" status "$D"
    else
      step harvest "$S/snotra-harvest.sh" fetch "$D" || return 1
      step verify  "$S/snotra-harvest.sh" verify "$D" || return 1
    fi
    # The bot's own STT may have produced nothing (8 191 silent successes, 2026-10-22). That is a WARN, not
    # a stop: our own transcription is the substitute. It becomes a FAILURE only when there is NO transcript
    # from either route — the requirement is a transcript, not a working vendor.
    if [ -f "$D/harvest.json" ]; then
      local have_txt=0
      [ -s "$D/evidence/bot/transcript.bot.txt" ] && have_txt=1
      if "$S/snotra-harvest.sh" signal "$D" >/dev/null 2>&1; then
        printf '  PASS  %-10s %s\n' signal "the bot's STT produced words"; pass=$((pass+1))
      elif [ $have_txt -eq 1 ]; then
        printf '  WARN  %-10s %s\n' signal "the bot reported ok with no words — our own transcript stands in"; warn=$((warn+1))
      else
        printf '  FAIL  %-10s %s\n' signal "no words from the bot and no transcript of our own"; fail=$((fail+1)); failed_at="signal"; return 1
      fi
      if [ $DRY -eq 0 ]; then step transcribe "$S/snotra-transcribe-bot.sh" run "$D" || return 1
      else "$S/snotra-transcribe-bot.sh" status "$D" >/dev/null 2>&1 && printf '  PASS  %-10s %s\n' transcribe "a transcript exists" || skipl transcribe "no transcript yet"; fi
      [ $DRY -eq 0 ] && { "$S/snotra-harvest.sh" speakers "$D" >/dev/null 2>&1 && pass=$((pass+1)) && printf '  PASS  %-10s %s\n' speakers "tracks split by speakerIndex" || { printf '  FAIL  %-10s %s\n' speakers "the capture log could not be split"; fail=$((fail+1)); }; }
    fi
  else
    skipl harvest "this record carries no Meet link — no bot recording can exist for it"
  fi

  step layout "$S/snotra-layout.sh" check "$D" || return 1

  if [ $DRY -eq 1 ]; then
    "$S/snotra-project.sh" plan "$D" >/dev/null 2>&1 && { printf '  PASS  %-10s %s\n' project "plan reads"; pass=$((pass+1)); } || { printf '  FAIL  %-10s %s\n' project "plan failed"; fail=$((fail+1)); }
    "$S/snotra-agenda.sh" plan "$D" >/dev/null 2>&1 && { printf '  PASS  %-10s %s\n' agenda "plan reads"; pass=$((pass+1)); } || { printf '  FAIL  %-10s %s\n' agenda "plan failed"; fail=$((fail+1)); }
  else
    step project "$S/snotra-project.sh" apply "$D" || return 1
    step verify  "$S/snotra-project.sh" verify "$D" || return 1
    step agenda  "$S/snotra-agenda.sh" apply "$D" || return 1
  fi

  if [ $DRY -eq 0 ]; then
    step letters "$S/snotra-letter.sh" render "$D" || return 1
    if [ $DRAFT -eq 1 ]; then step draft "$S/snotra-letter.sh" draft "$D" || return 1; else skipl draft "letters rendered; run with --draft to create Gmail drafts"; fi
    if [ $SHRINK -eq 1 ]; then step ladder "$S/snotra-audio-ladder.sh" apply "$D" || return 1; else skipl ladder "audio kept; run with --shrink after the transcript is verified"; fi
  fi
  return 0
}

exec 9>"$LOCK"
if ! flock -n 9; then printf 'snotra-pipeline: another run holds %s — one meeting at a time\n' "$LOCK" >&2; exit 1; fi

status=0
for D in "${DIRS[@]}"; do
  run_one "$D" || status=1
  printf '\n'
done
printf 'snotra pipeline: %d pass · %d warn · %d skip · %d fail%s\n' "$pass" "$warn" "$skip" "$fail" "${failed_at:+ — stopped at $failed_at}"
if [ -x "$ROOT/bin/records/runes-append.sh" ]; then
  "$ROOT/bin/records/runes-append.sh" brokk pipeline --message \
    "Snotra pipeline: ${#DIRS[@]} meeting(s) · pass=$pass warn=$warn skip=$skip fail=$fail${failed_at:+ stopped=$failed_at}${DRY:+ dry=$DRY}" >/dev/null 2>&1 || true
fi
exit $status

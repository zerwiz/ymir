#!/usr/bin/env bash
# test_acclaim_well.sh — a finished errand is remembered in the well (2026-11-12).
#
# The Allfather: "when they are DONE they need to remember what they have done to the well."
# The brief asks each worker for one episode before its terminal act. eindri-acclaim.sh is the
# backstop:
#
#   · `--terminal done` with no episode for the task → a LOUD warning and a minimal episode
#     written from --line, tagged `unremembered`
#   · `--terminal done` after the worker wrote its own → nothing more is written
#   · `--terminal failed` → remembered with its why
#
# The well is a throwaway log (ENGRAM_LOG, bridge pointed at a closed port), and acclaim runs
# from a copy of the tree that has no voice door and no reviewer, so no desktop notice is
# raised and no real record is touched. Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-acclaim-well.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tree/bin/agents" "$TMP/tree/bin/vault" "$TMP/tree/RULES" "$TMP/tree/.pi" "$TMP/state"
cp "$ROOT/bin/agents/eindri-acclaim.sh" "$ROOT/bin/agents/eindri-wake-lib.sh" "$TMP/tree/bin/agents/"
cp "$ROOT/bin/vault/hoard-lib.sh" "$TMP/tree/bin/vault/"
ln -s "$ROOT/bin/records" "$TMP/tree/bin/records"
ACCLAIM="$TMP/tree/bin/agents/eindri-acclaim.sh"
MIMIR="$ROOT/bin/records/mimir.sh"

export YMIR_HOME="$TMP/home" BROKK_ROOT_OVERRIDE="$TMP/tree" BROKK_STATE_OVERRIDE="$TMP/state"
export ENGRAM_LOG="$TMP/episodes.jsonl" MIMIRSBRUNN_URL="http://127.0.0.1:9" YMIR_AUTO_REVIEW=off
mkdir -p "$YMIR_HOME"
today="$(date -u +%Y-%m-%d)"
for id in forgot remembered broke; do printf 'launch_iso=%sT00:00:00Z\n' "$today" >"$TMP/state/$id.meta"; done

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$(printf '%s' "$2" | head -3 | tr '\n' ' ')"; }
count() { grep -c "\"$1\"" "$ENGRAM_LOG" 2>/dev/null || echo 0; }

out="$("$ACCLAIM" forgot --terminal done --line "opened PR one" 2>&1)"
printf '%s' "$out" | grep -q 'WARNING: the errand forgot finished (done) and left NO episode' \
  && ok "a forgotten episode is warned loudly" || bad "a forgotten episode is warned loudly" "$out"
grep -q 'eindri forgot done: opened PR one' "$ENGRAM_LOG" 2>/dev/null && grep -q 'unremembered' "$ENGRAM_LOG" \
  && ok "a minimal episode is written from --line" || bad "a minimal episode is written from --line" "$(cat "$ENGRAM_LOG" 2>&1)"

"$MIMIR" observe "remembered built the door; lesson: read the guard before trusting it" \
  --source eindri --task remembered --tags eindri,done --shape behaviour >/dev/null 2>&1
before="$(wc -l <"$ENGRAM_LOG")"
out="$("$ACCLAIM" remembered --terminal done --line "opened PR two" 2>&1)"
after="$(wc -l <"$ENGRAM_LOG")"
[ "$before" = "$after" ] && printf '%s' "$out" | grep -q 'left its own episode' \
  && ok "the worker's own episode is honoured, nothing doubled" || bad "the worker's own episode is honoured, nothing doubled" "$out"

out="$("$ACCLAIM" broke --terminal failed --line "the rail never answered" 2>&1)"
grep -q 'eindri broke failed: the rail never answered' "$ENGRAM_LOG" 2>/dev/null \
  && ok "a failed errand is remembered with its why" || bad "a failed errand is remembered with its why" "$out"

printf '\nacclaim-well: %s ok · %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]

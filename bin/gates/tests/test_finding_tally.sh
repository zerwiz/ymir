#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
export YMIR_HOME="${YMIR_HOME:-$HOME/Documents/ymirhome}"
# ensure config
mkdir -p "$YMIR_HOME/config" "$YMIR_HOME/state"
# clean findings for test
rm -f "$YMIR_HOME/state/review-findings.jsonl" "$YMIR_HOME/state/review-cards.md"
# add one
bin/forge/finding-log.sh add --class CHANGE_LOG_MISSING --rule R1 --file f.md --pr 1 --head abc >/dev/null
lines1=$(wc -l < "$YMIR_HOME/state/review-findings.jsonl")
bin/forge/finding-log.sh add --class CHANGE_LOG_MISSING --rule R1 --file f.md --pr 2 --head def >/dev/null
lines2=$(wc -l < "$YMIR_HOME/state/review-findings.jsonl")
[ "$((lines2-lines1))" = "1" ] || { echo "FAIL append"; exit 1; }
# vocab refusal
if bin/forge/finding-log.sh add --class NOPE --rule R --file f --pr 1 --head h 2>/dev/null; then echo "FAIL vocab"; exit 1; fi
# three in window opens one card
rm -f "$YMIR_HOME/state/review-findings.jsonl" "$YMIR_HOME/state/review-cards.md"
for i in 1 2 3; do bin/forge/finding-log.sh add --class CHANGE_LOG_MISSING --rule R --file f --pr $i --head h >/dev/null; done
out=$(bin/forge/finding-tally.sh --open-cards)
echo "$out" | grep -q "card: CHANGE_LOG_MISSING" || { echo "FAIL card"; exit 1; }
# second run opens none (count cards)
cards_before=$(grep -c "card:" "$YMIR_HOME/state/review-cards.md" 2>/dev/null || echo 0)
bin/forge/finding-tally.sh --open-cards >/dev/null
cards_after=$(grep -c "card:" "$YMIR_HOME/state/review-cards.md" 2>/dev/null || echo 0)
[ "$cards_before" = "$cards_after" ] || { echo "FAIL dedupe"; exit 1; }
echo "PASS"

#!/usr/bin/env bash
# garmr-bite-test.sh — the laws of the bite, proven offline (no real bite is ever taken here).
#
# The dangerous half of a guardian is the part that acts, so the suite proves the DECISION layer
# exhaustively and never performs a bite: every case runs `--dry-run` or the `--report`/`off`
# switches against a throwaway home. The act layer's safety is its record: every admissible bite
# carries its own undo command in the plan output, which is asserted here.
#
# Exit: 0 all pass · 1 a failure
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BITE="$ROOT/bin/ward/garmr-bite.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); printf '  PASS  %s\n' "$1"; else fail=$((fail+1)); printf '  FAIL  %s (want %s, got %s)\n' "$1" "$2" "$3"; fi; }
has()  { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }   # has <haystack> <needle>

mkhome() {  # <dir>
  mkdir -p "$1/config" "$1/state/garmr" "$1/hodd/memory"
  printf 'hound:\n  bite: %s\n' "${2:-contain}" > "$1/config/guardian.yaml"
}
FIND_EGRESS='{"class":"egress-unapproved","severity":"HIGH","dst":"185.220.101.5"}'
FIND_LISTEN='{"class":"listener-unknown","severity":"HIGH","port":9999}'

printf 'garmr_bite_test[7]{case,expectation}:\n'

# 1 · no rules file → every finding is a BARK (law 1)
T=$(mktemp -d); mkhome "$T" contain; printf '%s\n' "$FIND_EGRESS" > "$T/f.jsonl"
out=$(YMIR_HOME="$T" bash "$BITE" contain --dry-run --findings "$T/f.jsonl" 2>&1)
check "no rule, no bite" 1 "$(has "$out" 'nothing admissible' && echo 1 || echo 0)"
rm -rf "$T"

# 2 · a written rule + a non-peer destination → planned, with its own undo
T=$(mktemp -d); mkhome "$T" contain; cp "$ROOT/config/garmr-rules.example.yaml" "$T/config/garmr-rules.yaml"
printf '%s\n' "$FIND_EGRESS" > "$T/f.jsonl"
out=$(YMIR_HOME="$T" bash "$BITE" contain --dry-run --findings "$T/f.jsonl" 2>&1)
check "a written rule plans a bite" 1 "$(has "$out" 'egress-block' && echo 1 || echo 0)"
check "every bite names its undo"   1 "$(has "$out" 'nft delete rule' && echo 1 || echo 0)"

# 3 · a class that is not enabled is NOT planned, even when it matches a rule shape (law 1)
check "an unarmed class is a bark" 0 "$(has "$out" 'listener-close' && echo 1 || echo 0)"

# 4 · switch=report says what it would do and acts on nothing
printf 'hound:\n  bite: report\n' > "$T/config/guardian.yaml"
out=$(YMIR_HOME="$T" bash "$BITE" contain --findings "$T/f.jsonl" 2>&1)
check "report mode acts on nothing" 1 "$(has "$out" 'WOULD BITE (switch: report)' && echo 1 || echo 0)"

# 5 · switch=off only barks
printf 'hound:\n  bite: off\n' > "$T/config/guardian.yaml"
out=$(YMIR_HOME="$T" bash "$BITE" contain --findings "$T/f.jsonl" 2>&1)
check "off mode only barks" 1 "$(has "$out" 'BARKED (switch: off)' && echo 1 || echo 0)"

# 6 · planning has no side effects: nothing new in the state dir
before=$(find "$T/state" -type f | wc -l)
YMIR_HOME="$T" bash "$BITE" contain --dry-run --findings "$T/f.jsonl" >/dev/null 2>&1
after=$(find "$T/state" -type f | wc -l)
check "a plan writes nothing" "$before" "$after"

# 7 · the allowlist is exactly six bites, and revocation is refused by design
out=$(YMIR_HOME="$T" bash "$BITE" allowlist 2>&1)
check "six bites and no more" 6 "$(printf '%s\n' "$out" | grep -c '^  "')"
check "a token is never un-revoked" 1 "$(has "$out" 'revoked in place' && echo 1 || echo 0)"
rm -rf "$T"

# 8-10 · the advisor: it may propose, it may never act, and it only speaks in the allowlist
T=$(mktemp -d); mkhome "$T" contain; printf '%s\n' "$FIND_EGRESS" > "$T/f.jsonl"
out=$(GARMR_ADVISOR_CMD="echo 'egress-block 1.2.3.4'" YMIR_HOME="$T" bash "$BITE" advise "$T/f.jsonl" 2>&1)
check "an advisor inside the allowlist proposes" 1 "$(has "$out" 'advisor,proposal' && echo 1 || echo 0)"
check "a proposal still needs a written rule"     1 "$(has "$out" 'the rules dispose' && echo 1 || echo 0)"
out=$(GARMR_ADVISOR_CMD="echo 'rm -rf /'" YMIR_HOME="$T" bash "$BITE" advise "$T/f.jsonl" 2>&1)
check "an answer outside the allowlist is discarded" 1 "$(has "$out" 'discarded' && echo 1 || echo 0)"
out=$(GARMR_ADVISOR_CMD="" YMIR_HOME="$T" bash "$BITE" advise "$T/f.jsonl" 2>&1)
check "no advisor is the safe default" 1 "$(has "$out" 'rule alone' && echo 1 || echo 0)"
rm -rf "$T"

# 14-15 · the model in the RESPONSE path: it may suggest, it may not widen a rule
T=$(mktemp -d); mkhome "$T" contain; cp "$ROOT/.agents/config/garmr-rules.example.yaml" "$T/config/garmr-rules.yaml"
printf 'hound:\n  bite: contain\n  model: on\n' > "$T/config/guardian.yaml"
printf '%s\n' '{"class":"intrusion-suspected","severity":"CRITICAL","port":9999}' > "$T/f.jsonl"
out=$(GARMR_ADVISOR_CMD="echo 'listener-close 9999'" YMIR_HOME="$T" bash "$BITE" contain --dry-run --findings "$T/f.jsonl" 2>&1)
check "an unarmed class refuses even on advice" 1 "$(has "$out" 'REFUSED to act' && echo 1 || echo 0)"
# arm the class → the DETERMINISTIC path bites, with no model at all
python3 - "$T/config/garmr-rules.yaml" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); p.write_text(p.read_text().replace("# - listener-unknown", "- listener-unknown"))
PY
printf '%s\n' '{"class":"listener-unknown","severity":"CRITICAL","port":9999}' > "$T/f.jsonl"
out=$(GARMR_ADVISOR_CMD="" YMIR_HOME="$T" bash "$BITE" contain --dry-run --findings "$T/f.jsonl" 2>&1)
check "an armed class bites without a model" 1 "$(has "$out" 'listener-close' && echo 1 || echo 0)"
rm -rf "$T"

printf '\ngarmr_bite[2]{passed,failed}:\n  "%s","%s"\n' "$pass" "$fail"
[ "$fail" = 0 ] || exit 1

#!/usr/bin/env bash
# Unit test for erindi-brief.sh --mode batch — RULES/08, the batch road (appended 2026-11-12).
# A batch errand commits on eindri/<id>, never pushes, never opens a PR, remembers its work in
# the well and acclaims "committed on eindri/<id> (not pushed)" so bin/forge/gather.sh finds it.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/data" "$TMP/state"
run() { BROKK_DATA_OVERRIDE="$TMP/data" BROKK_STATE_OVERRIDE="$TMP/state" bash "$ROOT/bin/agents/erindi-brief.sh" "$@"; }

run t-batch ymir --mode batch >/dev/null 2>&1 && ok "a batch brief scaffolds" || bad "a batch brief was refused"
B="$TMP/data/t-batch/brief.md"
grep -q '^Delivery contract: mode=batch$' "$B" && ok "the contract line says mode=batch" || bad "no mode=batch contract line"
grep -q 'Never push to any remote and never open a PR' "$B" && ok "rule 1 forbids push and PR" || bad "rule 1 does not forbid the push"
grep -q 'committed on eindri/t-batch (not pushed)' "$B" && ok "the acclaim says committed, not pushed" || bad "the acclaim line is missing"
grep -q 'mimir.sh observe' "$B" && ok "the brief asks for the well record" || bad "the brief does not ask for the well"
grep -q 'git push' "$B" && bad "a batch brief still names git push" || ok "a batch brief names no git push"
grep -q 'gh pr create' "$B" && bad "a batch brief still names gh pr create" || ok "a batch brief names no gh pr create"
run t-bad ymir --mode bogus >/dev/null 2>&1 && bad "an unknown mode was accepted" || ok "an unknown mode is still refused"

printf '\n%s\n' "----------------------------------------"
if [ "$fail" = 0 ]; then printf 'erindi-brief-batch.test.sh: all passed\n'; else printf 'erindi-brief-batch.test.sh: FAILED\n' >&2; fi
exit "$fail"

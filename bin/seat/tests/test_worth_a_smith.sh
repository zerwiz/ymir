#!/usr/bin/env bash
# test_worth_a_smith.sh — a short question is answered in hand; a long brief that quotes one is seated; and a
# refusal names its real cause (plan 369 item 15). Only the verdict verb runs: nothing is seated.
set -u
ROOT="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
RUN="$ROOT/bin/seat/herdr-run.sh"
fail=0; ok() { printf 'ok   %s\n' "$1"; }; no() { printf 'FAIL %s\n' "$1"; fail=1; }
judge() { # <label> <text> <exit> <phrase>
  local out rc
  out="$(bash "$RUN" worth-a-smith "$2" 2>&1)"; rc=$?
  if [ "$rc" = "$3" ] && printf '%s' "$out" | grep -qF -- "$4"; then ok "$1"; else no "$1 (rc=$rc: $out)"; fi
}

long='Build the new pages for the site from the brief in the home. The operator asked "is it possible to add this to more pages?" and wants it on every product page with a test and a short note.'
judge 'a long brief that quotes a question is seated' "$long" 0 '"yes"'
judge 'a long brief that opens with a question word is seated' "what is broken: the clock retires after a flip. Find the cause in the starter, fix it, add a test that fails first, write one fix note and report to the helm." 0 '"yes"'
judge 'a long brief ending in a question mark is seated' "fix the reader so a grey suggestion is never typed text, add the byte line as a test, write the fix note, commit on a branch and tell me, can you do that today?" 0 '"yes"'
judge 'a short question is answered in hand' 'is the clock running on this machine?' 1 'a question'
judge 'a short lookup is answered in hand' 'show me the last cron log lines' 1 'a question'
judge 'a short task that quotes a question mid-text is a task' 'fix the "ready?" button label on the settings page' 0 '"yes"'
judge 'a two-word errand is too brief, and says so' 'fix it' 1 'too brief'
grep -q 'too brief — answer it in hand' "$ROOT/bin/agents/eindri-start.sh" \
  && no 'eindri-start still prints one verdict for every refusal' || ok 'eindri-start prints the reason herdr-run gave'

[ "$fail" = 0 ] && echo "test_worth_a_smith: PASS" || echo "test_worth_a_smith: FAIL"
exit "$fail"

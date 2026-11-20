#!/usr/bin/env bash
# Tests for the meeting ladder and the ear's voice. Run: bash tests/test_snotra_ladder.sh
#
# THE TWO THINGS THIS PROVES, and they are the two the plan is judged by (plan 228 §2–§3):
#   1. a step that FAILS is reported — in the meeting's own `.state`, on the hotline, and in
#      `snotra-what.sh last` / `plan`, which stop claiming the pipeline finished;
#   2. a step that FINISHED is not reported as a stop, and its promises are todos in the
#      same act.
#
# Everything runs on a fixture home and a fixture state dir, so no house data is touched
# and no notification leaves the machine (`SNOTRA_LADDER_NOTIFY_LOG` holds the hotline).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
LADDER="$ROOT/bin/records/snotra-ladder.sh"
WHAT="$ROOT/bin/records/snotra-what.sh"
BOARD="$ROOT/bin/records/todos.sh"
MEETINGS="$ROOT/bin/records/meetings.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL %s — %s\n' "$1" "${2-}"; }
check(){ local name=$1; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }
refute(){ local name=$1; shift; if "$@" >/dev/null 2>&1; then bad "$name" "expected failure"; else ok "$name"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export YMIR_HOME="$TMP/home"
export YMIR_STATE_DIR="$TMP/state"
export SNOTRA_LADDER_NOTIFY_LOG="$TMP/hotline.log"
export SNOTRA_WATCH_UNIT="snotra-selftest-no-such-unit.service"
export SNOTRA_LADDER_QUIET=0
mkdir -p "$YMIR_STATE_DIR" "$YMIR_HOME/hodd/life/meetings/self"

# the GOOD meeting is the NEWER one, so `last` (which reads the newest) is the one this
# test changes its mind about — otherwise the stopped meeting would always be "last".
good="$YMIR_HOME/hodd/life/meetings/self/2026-01-04-good"
bad_dir="$YMIR_HOME/hodd/life/meetings/self/2026-01-03-bad"
mkdir -p "$good" "$bad_dir"
printf '%s\n' '{"id":"2026-01-04-good","title":"The good call","started_at":"2026-01-04T10:00:00","state":"captured"}' >"$good/meeting.json"
printf '%s\n' '{"id":"2026-01-03-bad","title":"The bad call","started_at":"2026-01-03T10:00:00","state":"captured"}' >"$bad_dir/meeting.json"
printf '# Transcript\n\nAllfather: we will send the minutes by Friday.\nAnna: I will book the room.\n' >"$good/transcript.md"
printf 'captured\n' >"$good/.state"
printf 'captured\n' >"$bad_dir/.state"

# the model's seat, replaced for the test only — the composer contract, nothing more
cat >"$TMP/composer.sh" <<'SH'
#!/usr/bin/env bash
printf '# Minutes — the test call\n\n## Present\n%s\n\n## Decisions\n- the minutes go out on Friday\n\n## Promises\n- [ ] send the minutes · owner Allfather · due Friday\n- [ ] book the room · owner Anna · due unrepeated\n\n## Notes\nnone\n' "${2:-nobody}"
SH
chmod +x "$TMP/composer.sh"

# ── 1 · a step that FAILS is reported ──────────────────────────────────────
refute "a meeting with no transcript and no audio fails" \
  env SNOTRA_MINUTES_COMPOSER="$TMP/composer.sh" bash "$LADDER" run "$bad_dir"
check "its own state carries the stop sentence" \
  bash -c "head -1 '$bad_dir/.state' | grep -q '^stopped at transcript: '"
check "the hotline heard the stop" \
  bash -c "grep -q 'stopped at transcript' '$SNOTRA_LADDER_NOTIFY_LOG'"
check "snotra-what last says STOPPED" \
  bash -c "bash '$WHAT' last | grep -q 'STOPPED'"
refute "snotra-what last never claims FINISHED for it" \
  bash -c "bash '$WHAT' last | grep -q 'FINISHED'"
check "snotra-what plan names the blocked rung" \
  bash -c "bash '$WHAT' plan 2026-01-03-bad | grep -q 'blocked at: transcript'"
check "no minutes were written for a stopped run" test ! -s "$bad_dir/minutes.md"
check "meetings.sh reports the stop in its state column" \
  bash -c "bash '$MEETINGS' state 2026-01-03-bad | grep -q 'stopped at transcript'"

# ── 2 · a step that FINISHES is not reported as a stop ─────────────────────
check "the good meeting finishes the ladder" \
  env SNOTRA_MINUTES_COMPOSER="$TMP/composer.sh" bash "$LADDER" run "$good"
check "state is dispatched" bash -c "test \"\$(head -1 '$good/.state')\" = dispatched"
check "minutes landed in the meeting's own folder" test -s "$good/minutes.md"
check "promises landed beside them" test -s "$good/actions.md"
check "the todos equal the promises" \
  bash -c "bash '$BOARD' list --meeting 2026-01-04-good --json | python3 -c 'import json,sys; assert len(json.load(sys.stdin))==2'"
check "the minutes rung spoke" bash -c "grep -q 'minutes filed' '$SNOTRA_LADDER_NOTIFY_LOG'"
refute "a finished ladder never reports a stop" \
  bash -c "grep -q '2026-01-04-good' '$SNOTRA_LADDER_NOTIFY_LOG' && grep 'stopped' '$SNOTRA_LADDER_NOTIFY_LOG' | grep -q '2026-01-04-good'"
refute "snotra-what last says STOPPED for a finished meeting" \
  bash -c "bash '$WHAT' last | grep -q 'STOPPED'"
check "snotra-what last says FINISHED for it" bash -c "bash '$WHAT' last | grep -q 'FINISHED'"

# a second run files nothing twice (the promise count is the todo count, always)
SNOTRA_MINUTES_COMPOSER="$TMP/composer.sh" bash "$LADDER" run "$good" >/dev/null 2>&1
check "re-running the ladder files no duplicate todos" \
  bash -c "bash '$BOARD' list --meeting 2026-01-04-good --json | python3 -c 'import json,sys; assert len(json.load(sys.stdin))==2'"

# ── 3 · the ear's own voice, on the same fixture ───────────────────────────
printf '%s\n' '{"phase":"idle"}' >"$YMIR_STATE_DIR/.snotra-detect.json"
check "snotra-what now answers an idle watch" bash -c "bash '$WHAT' now | grep -qi 'watching\\|idle\\|armed'"
check "snotra-what off records his reason" bash "$WHAT" off --reason "a room that must not be recorded"
check "now reports the off and its reason" bash -c "bash '$WHAT' now | grep -q 'must not be recorded'"
check "on lifts it" bash "$WHAT" on
check "the ladder self-test passes" bash "$LADDER" --self-test
check "the ear's self-test passes" bash "$WHAT" --self-test

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

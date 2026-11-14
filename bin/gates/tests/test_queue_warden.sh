#!/usr/bin/env bash
# test_queue_warden.sh — the warden is HYGIENE, and the proof is the absence of a merge.
#
# Plan 290, 2026-11-14 11:38 CET (the heart's ruling): the queue-warden never merges, never forces,
# never commits with --no-verify, never closes another hand's work, and never writes to GitHub as a
# person. This test proves the ROAD IS GONE, not merely that a run exits 0: the judge reads the
# CODE — every comment line stripped first — because a comment that says "never merges" proves
# nothing, and prose about a law is not the law.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WARDEN="$ROOT/bin/forge/queue-warden.sh"
PASS=0; FAIL=0
t() { if [ "$1" = "0" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$2"; fi; }
CODE="$(grep -vE '^[[:space:]]*#' "$WARDEN" 2>/dev/null)"
present() { printf '%s\n' "$CODE" | grep -qE "$1"; }          # t $? — must exist in the code
absent()  { if present "$1"; then return 1; else return 0; fi; }  # t $? — must NOT exist

# 1. it is a door
[ -x "$WARDEN" ]; t $? "script exists/executable"
bash -n "$WARDEN" 2>/dev/null; t $? "syntax"

# 2. the merge road is GONE — no call of any spelling can merge through this file
absent 'gh +pr +merge'; t $? "no 'gh pr merge' in the code"
absent 'pr merge'; t $? "no PR merge call of any spelling"
absent '(pulls/[^ ]*|api).*(merge|PUT)'; t $? "no merge through the API"
absent 'pr (close|reopen)'; t $? "the warden closes nothing"
absent 'git add -A'; t $? "no blanket 'git add -A'"
absent '[-][-]no-verify'; t $? "no --no-verify"
absent 'YMIR_SKIP_[A-Z_]+'; t $? "no gate override is exported or set"
absent 'push[^|]*(--force|-f[[:space:]]|\+refs/|--mirror)'; t $? "no forced or mirrored push"
absent 'git merge'; t $? "nothing is merged into a branch"

# 3. the ways it DOES act are the three hygiene acts, and the machine identity gates the ONE write
present 'worktree add'; t $? "the re-cut seats a worktree"
present 'rebase origin/main'; t $? "the re-cut rebases onto origin/main"
present 'rehygiene/'; t $? "the re-cut lands on a NEW branch, never theirs"
present 'CREDENTIAL" != "machine"'; t $? "the push is gated on the machine identity, not on whoever is logged in"
present 'push origin "refs/heads/\$new:refs/heads/\$new"'; t $? "the only push is the new branch, unforced"

# 4. a stale PR is a NOTICE, never a close
present 'stale_hours'; t $? "staleness is configurable"
present 'the helm decides, this warden never closes'; t $? "a stale PR is flagged and left standing"
present 'max_open_prs'; t $? "the cap is configurable in the operator's home"
present 'over-cap'; t $? "the cap is reported"

# 5. the clock is SEATED, not STARTED, unless asked
present 'START_TIMER'; t $? "the timer needs an explicit --start"
present 'systemctl --user disable "\$TIMER"'; t $? "a bare install leaves the timer stopped, not started"
grep -q 'SEATING IS NOT STARTING' "$WARDEN"; t $? "the source states the rule it obeys"

# 6. a dry run reads the open PRs and merges nothing
out="$(bash "$WARDEN" run --dry-run 2>&1)"; t $? "dry-run runs"
printf '%s\n' "$out" | grep -q 'warden-pass'; t $? "dry-run reports a pass"
printf '%s\n' "$out" | grep -qE '^  "[^"]*","[^"]*","[^"]*","[^"]*","[^"]*","[^"]*","[^"]*","[^"]*","[^"]*","0"$'; t $? "the pass reports a merge count of zero"
case "$out" in
  *"merged PR"*) FAIL=$((FAIL+1)); printf 'FAIL: a dry run said a PR was merged\n' ;;
  *) PASS=$((PASS+1)) ;;
esac

# 7. one PR can be named
bash "$WARDEN" run --dry-run --pr 1 >/dev/null 2>&1; t $? "--pr is accepted"

# 8. the policy is readable without acting
bash "$WARDEN" status 2>/dev/null | grep -q 'queue-warden\[9\]'; t $? "status prints the resolved policy"
bash "$WARDEN" --timer-status >/dev/null 2>&1; t $? "--timer-status is read-only and exits 0"
bash "$WARDEN" --bogus-flag >/dev/null 2>&1
[ $? -eq 2 ]; t $? "an unknown flag is refused (exit 2)"

printf 'queue-warden tests: %d pass, %d fail\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

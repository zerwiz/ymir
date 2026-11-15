#!/usr/bin/env bash
# test_queue_warden.sh — the warden is HYGIENE, and its one merge is the heart's, behind one gate.
#
# Plan 290, 2026-11-14 (the heart's ruling, then the Allfather's word): the warden's job is queue
# hygiene — cap, stale, re-cut, solve conflicts — and a merge is the one act it may not take on
# trust. So the merge road is (1) CLOSED unless this machine's own wardens file says `merge: on`,
# (2) closed unless this machine's ROLE is the heart, and (3) where open, gated by
# `bin/forge/merge-verdict.sh` and nothing else. Every fault of the old door is gone: no forced
# push, no `--no-verify`, no `git add -A`, no `YMIR_SKIP_*`, no close.
#
# The judge reads the CODE — every comment line stripped first — because a comment that says
# "never merges" proves nothing, and prose about a law is not the law.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WARDEN="$ROOT/bin/forge/queue-warden.sh"
PASS=0; FAIL=0
t() { if [ "$1" = "0" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$2"; fi; }
CODE="$(grep -vE '^[[:space:]]*#' "$WARDEN" 2>/dev/null)"
present() { printf '%s\n' "$CODE" | grep -qE "$1"; }                 # t $? — must exist in the code
absent()  { if present "$1"; then return 1; else return 0; fi; }     # t $? — must NOT exist

# 1. it is a door
[ -x "$WARDEN" ]; t $? "script exists/executable"
bash -n "$WARDEN" 2>/dev/null; t $? "syntax"

# 2. every fault of the old door is GONE
absent 'git add -A'; t $? "no blanket 'git add -A'"
absent '[-][-]no-verify'; t $? "no --no-verify"
absent 'YMIR_SKIP_[A-Z_]+'; t $? "no gate override is exported or set"
absent 'push[^|]*(--force|-f[[:space:]]|\+refs/|--mirror)'; t $? "no forced or mirrored push"
absent 'pr (close|reopen)'; t $? "the warden closes nothing"
absent 'git merge'; t $? "nothing is merged into another hand's branch"

# 3. the merge road is CLOSED by default, and only the heart's own file can open it
present 'merge: off in this machine'; t $? "the road names its closure"
present 'MERGE_POLICY" = "on"'; t $? "the road needs merge: on in the machine's own file"
present '" heart "'; t $? "the road needs the heart ROLE, read from the registry"
present 'only the heart may merge'; t $? "a non-heart machine with merge: on is refused in words"
present 'merge-verdict.sh'; t $? "the gate is named"
present 'merge-verdict.sh is not on this tree'; t $? "a missing gate closes the road rather than opening it"

# 4. there is exactly ONE merge call, it lives in merge_one, and the gate is in that same function
n="$(printf '%s\n' "$CODE" | grep -c 'gh pr merge')"
[ "$n" = "1" ]; t $? "exactly one merge call in the whole file (found: ${n:-0})"
merge_fn="$(printf '%s\n' "$CODE" | awk '/^merge_one\(\)/{f=1} f{print} f&&/^}/{exit}')"
printf '%s' "$merge_fn" | grep -q 'merge-verdict.sh'; t $? "the gate is inside the only merge function"
printf '%s' "$merge_fn" | grep -q 'gh pr merge'; t $? "the only merge call is inside it"
printf '%s\n' "$CODE" | grep -A1 'MERGE_OPEN" = 1' | grep -q 'merge_one'; t $? "merge_one is called only when the road answered open"
printf '%s\n' "$CODE" | grep -q 'merge-verdict.sh" "\$n"'; t $? "the gate is called verbatim, with the PR"

# 5. the ways it DOES act are the hygiene acts
present 'worktree add'; t $? "the re-cut seats a worktree"
present 'rebase origin/main'; t $? "the re-cut rebases onto origin/main"
present 'rehygiene/'; t $? "the re-cut lands on a NEW branch, never theirs"
present 'CREDENTIAL" != "machine"'; t $? "the push is gated on the machine identity, not on whoever is logged in"
present 'push origin "refs/heads/\$new:refs/heads/\$new"'; t $? "the only push is the new branch, unforced"

# 6. a stale PR is a NOTICE, never a close; the cap is the home's
present 'stale_hours'; t $? "staleness is configurable"
present 'the helm decides, this warden never closes'; t $? "a stale PR is flagged and left standing"
present 'max_open_prs'; t $? "the cap is configurable in the operator's home"
present 'over-cap'; t $? "the cap is reported"

# 7. the layout the shared library decided: `enabled`, no `wardens:` wrapper, read through its door
present 'enabled'; t $? "the per-machine opt-in is named 'enabled'"
absent 'wardens:'; t $? "no wardens: wrapper in the reader"
present 'warden-policy.py'; t $? "the shared reader is called"
present 'POLICY_READER="shared"'; t $? "which reader answered is recorded, so a fallback cannot pose as the library"
absent 'blk = \(\$1 == "wardens:"\)'; t $? "the local fallback reads the door's own block at the top level"

# 8. the clock is SEATED, not STARTED, and not even started on request when the machine is off
present 'START_TIMER'; t $? "the timer needs an explicit --start"
present 'systemctl --user disable "\$TIMER"'; t $? "a bare install leaves the timer stopped"
present 'START_TIMER" = 1 \] && \[ "\$ENABLED"'; t $? "--start cannot start a clock on a machine that has not opted in"
present 'INVOCATION_ID'; t $? "a SCHEDULED pass is told apart from a hand's"

# 9. a dry run reads the open PRs and merges nothing
out="$(bash "$WARDEN" run --dry-run 2>&1)"; t $? "dry-run runs"
printf '%s\n' "$out" | grep -q 'warden-pass'; t $? "dry-run reports a pass"
printf '%s\n' "$out" | grep -qE '^  "[^"]*"(,"[^"]*"){9},"0","[^"]*"$'; t $? "the pass reports a merge count of zero"
printf '%s' "$out" | grep -q 'merge_road'; t $? "the pass states whether the road is open"
case "$out" in
  *"merged with"*) FAIL=$((FAIL+1)); printf 'FAIL: a dry run said it merged\n' ;;
  *) PASS=$((PASS+1)) ;;
esac

# 10. one PR can be named, the policy is readable without acting, a bad flag is refused
bash "$WARDEN" run --dry-run --pr 1 >/dev/null 2>&1; t $? "--pr is accepted"
bash "$WARDEN" status 2>/dev/null | grep -q 'queue-warden\[12\]'; t $? "status prints the resolved policy"
bash "$WARDEN" status 2>/dev/null | grep -qE 'closed: merge|open: the heart'; t $? "status states the merge road in words"
bash "$WARDEN" --timer-status >/dev/null 2>&1; t $? "--timer-status is read-only and exits 0"
bash "$WARDEN" --bogus-flag >/dev/null 2>&1
[ $? -eq 2 ]; t $? "an unknown flag is refused (exit 2)"

printf 'queue-warden tests: %d pass, %d fail\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

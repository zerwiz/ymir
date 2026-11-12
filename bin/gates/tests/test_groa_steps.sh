#!/usr/bin/env bash
# test_groa_steps.sh — plan 272 fault 5: every Gróa step has a limit and says where it is.
# Before: an apply that stalled ran past the caller's 590 s timeout with no word of WHICH step stopped.
# The step wrapper is lifted out of groa-update.sh itself, so the test judges the shipped code.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
G="$ROOT/bin/agents/groa-update.sh"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

SCRIPT_DIR="$ROOT/bin/agents"
src="$(sed -n '/^GSTEP_STOPPED=/,/^}/p' "$G")"
[ -n "$src" ] && ok "the step wrapper is in groa-update.sh" || { bad "no wrapper"; exit 1; }
. "$ROOT/bin/time/sol-lib.sh"
eval "$src"

out="$( { exec 7>&2; gstep quick 5 true; } 2>&1 )"
printf '%s' "$out" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} .+ — step quick: ok in [0-9]+s$' && ok "a finished step prints its stamp, name and time" || bad "ok line: $out"

t0=$SECONDS
out="$( { exec 7>&2; gstep slowone 1 sleep 30; } 2>&1 )"; rc=$?
el=$((SECONDS - t0))
printf '%s' "$out" | grep -q 'step slowone: STOPPED at its 1s limit' && ok "a stalled step is STOPPED at its limit and named" || bad "stopped line: $out"
[ "$el" -lt 10 ] && ok "it stopped in ${el}s, not after the 30s it wanted" || bad "did not stop: ${el}s"

out="$( { exec 7>&2; gstep broken 5 false; } 2>&1 )"
printf '%s' "$out" | grep -q 'step broken: failed (rc=1)' && ok "a failing step is named with its code" || bad "failed line: $out"

out="$( { exec 7>&2; YMIR_GROA_STEP_TIMEOUT_SLOWTWO=1 gstep slowtwo 100 sleep 30; } 2>&1 )"
printf '%s' "$out" | grep -q 'STOPPED at its 1s limit' && ok "a per-step limit can be set by environment" || bad "env limit: $out"

# every step that can wait in the apply path goes through the wrapper
for step in bilskirnir electron hnoss eir codex-plugin harness-extensions valknut-load home-seed units-write pin-deploy migrate; do
  grep -q "gstep $step " "$G" && ok "the $step step is bounded" || bad "the $step step is unbounded"
done
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

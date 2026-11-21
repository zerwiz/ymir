# The update loop's proof record named a test fixture as the failed gate

**Date:** 2026-11-20 · **Component:** engine (`bin/engine/tests/test_update_loop_proof.sh`) · **Errand:** `open-ends`

## What was wrong

The heart's update loop holds `149f38ebd294` as *not proven*, and its record reads
`bin/gates/ci-verify.sh exited 1` with the failed row `"fixture","FAIL","the suite is red on purpose …"`.

That row is not a gate. It is the fixture inside `test_update_loop_proof.sh`, which the real `ci-verify.sh` runs.
The loop writes its proof log to `${TMPDIR:-/tmp}/ul-prove.log`, and the test did not set its own `TMPDIR`. So the
fixture loop truncated and rewrote the real loop's log while the real suite was still writing it. The log was left
as a run of blanks with the fixture's row on top, and the real failed gate was lost.

## What was built

The test makes `$T/tmp` and exports `TMPDIR` before the loop runs, so the fixture's log is its own.

## Proof

`bash bin/engine/tests/test_update_loop_proof.sh` — 16 passed. The real red gate behind the heart's hold must be
re-measured once this lands: `bin/engine/update-loop.sh prove 149f38ebd294 --force` (or the next main, proved fresh).

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #856

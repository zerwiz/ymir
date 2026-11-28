# The self-exec test runs in the gate

**Date:** 2026-11-27

## What was wrong

`bin/fleet/tests/test_no_stub_execs_itself.sh` was merged without a row in `bin/gates/checks.d/`, so nothing ran it.

## The fix

The row `bin/gates/checks.d/9120-no-self-exec.sh` runs it in the whole-tree gate.

## Proof

The test passes through that command.

## CHANGE LOG

- 2026-11-27 — written with the fix.

# Main was red on three old faults

**Date:** 2026-11-27

## What was wrong

Four rows of the whole-tree gate failed on `main` itself, so no pull request could go green:

1. `everything-up`: `eindri-acclaim.sh` named the report shelf by a relative path (`state/eindri-reports/…`).
2. `mocks-vocabulary` and `compliance`: the scan read generated `INDEX.md` rows quoting "a forwarding stub, plan N" as
   unfinished code.
3. `opencode-launcher`: the test removed the env prefix and quotes from the expected line only, not from the printed one.

## The fix

The acclaim detail names the shelf under the resolved state directory. The scan excuses that one kind of index row. The
test normalises both lines the same way.

## Proof

The four checks fail on `main` before this change and pass after it.

## CHANGE LOG

- 2026-11-27 — written with the fix.

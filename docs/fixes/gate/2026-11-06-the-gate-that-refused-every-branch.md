# The push gate refused every branch while `origin/main` was red — and gave the reason it was not ours

**When:** 2026-11-06, late.
**Component:** `bin/gates/guards.sh` (the aggregate door behind `.githooks/pre-push`).

## What was wrong

`guards.sh` ran every tree ward, collected the failures, then **measured whose fault each one
was** — a throwaway worktree at `origin/main`, each failing ward re-run there — and printed the
answer:

```
guards: 1 of 1 failing ward(s) are red on origin/main, not on this branch
guards: a ward found a fault — see the FAIL row above
error: failed to push some refs
```

It said, in one line, that the fault was not the branch's. It then refused the push anyway,
because `fail` was already 1 and nothing was ever decided from `also`.

**The consequence was a deadlock, not an inconvenience.** A branch that was green on every ward
could not be pushed while `origin/main` carried a red one — and neither could the commit that
would have repaired `origin/main`, because that commit is a branch too. Measured this night:
five refusals in a row on a branch whose every ward passed when run by hand.

## What was done

One decision, added where the measurement already existed:

- every failing ward also red on `origin/main` → **the push proceeds**, with `CLEARED` printed
  loudly and the `main_baseline` table above it, so nobody reads the branch as green;
- any failure that is the branch's own → the refusal stands, unchanged;
- the baseline could not be measured (no `origin/main`, or the throwaway worktree would not come
  up) → the refusal stands, because unknown is not permission.

## Proven

A fixture with two fake wards, in `/tmp`, at three states of `origin/main`:

| Case | Failing wards | Red on main | Result |
|---|---|---|---|
| every failure is main's | 2 | 2 | `CLEARED`, exit 0 |
| one failure is the branch's own | 2 | 1 | refusal, exit 1 |
| a ward the branch broke | 1 | 0 | refusal, exit 1 |

The real repository then pushed, having been refused five times by the old logic.

## What this does not do

It does not soften a ward. A red ward is still red, still printed, still in the `main_baseline`
table — the gate stops pretending a branch is broken when the tree underneath it is. The hand that
owns `origin/main` still owes the repair, and CI keeps the last word.

### CHANGE LOG

- **2026-11-07** — written with the hook change it describes.

# A keeper can find its own memory — the well's three gaps closed

**2026-10-24.** Component: `bin/records/mimir.sh` (recall), `bin/records/well-selftest.sh` (new).

## The three gaps, measured the same day (plan 129 §21)

1. **`recall` had no scope.** No `--tag`, `--actor` or `--since`: a keeper asking "what did I do" got the whole
   house's episodes, and there was no way to ask otherwise.
2. **`--tags` was accepted and silently ignored.** `recall … --tags domain:snotra` returned an unrelated episode
   and printed no warning — the exact "yes that means nothing" class of fault the day kept producing.
3. **Write-then-read did not hold.** An episode written seconds earlier was in the store (grep proved it) and was
   **not** returned by a query built from its own words: the semantic index lags the store, and an empty answer
   from the index was reported as an empty answer from the well.

## What changed

- **Filters are real**: `--tag`/`--tags`, `--actor`, `--since YYYY-MM-DD`, applied in one printer used by both
  paths, so a filtered row looks the same whichever door found it.
- **An unknown flag is refused** (exit 2) with the usage line — never ignored.
- **The store is the fallback, not an afterthought.** When the bridge returns no rows, recall searches the store
  itself, filtered by the same rules. An empty answer now means *nothing recorded*; it can no longer mean *not
  indexed yet*, which is a different fact and a different lie to a keeper.

## Proof (`bin/records/well-selftest.sh`, four checks, all passing)

```
  observe under a unique tag         PASS
  recall scoped to its own tag       PASS (1 row)
  a wrong tag returns nothing        PASS
  an unknown flag is refused         PASS
well-selftest[1]{fails,state}:
  0,"PASS"
```

And by hand, against the live well: the probe episode is returned under `--tag domain:snotra` (1 row) and hidden
under `--tag domain:nornir` (0 rows) — which is the whole point: a keeper sees its own memory and not its
neighbour's.

## Owed

- The bridge's index should eventually hold what was just written; until it does, the fallback carries the answer
  and the test keeps it honest.
- `observe` still takes only `--tags/--source`; a `--namespace domain:<keeper>` spelling would make the register and
  the well speak one word (plan 129 §21.4).

# seat · unversioned · 2026-11-14 — the test proved a road nobody runs

Section 7 of `bin/seat/tests/test_everything_up.sh` proves that Gróa **records** what she found: the
daily log, the Runes ledger, and the well when the tree moved — and nothing at all when nothing moved.
Three checks went red on `main`; the code was right and the test was stale.

## The cause

The test seats a fake `opencode` on `PATH` and lets Gróa's body run. Until **#721** (`e1574bcb`,
plan 275 S8b, 2026-11-13) that was the only body there was. #721 gave Gróa two roads and made
`GROA_MODE=script` the default: she now runs the tree's own `bin/agents/groa-update.sh`, and the
leashed model is asked for explicitly.

The test never said `GROA_MODE=agent`, so after #721 it was running the **script** road against a fake
repo with no `groa-update.sh`: the run failed, Gróa filed a `GUARD:` line, and the record wrote two
entries where the test expected three or none.

## What changed

- The agent-road checks now say **`GROA_MODE=agent`** — the stub on `PATH` is an `opencode`, so the
  road under test must be the agent road.
- **The shipped default road is now proved too.** A second fake tree with `git init` and a stub
  `groa-update.sh` runs under `GROA_MODE=script` and must write the same three records when the tree
  moved, and none when it did not.

That is the part that matters: the regression happened *because* the default road had no test. It has
one now.

The test's scratch home was also renamed (`$work/home` → `$work/fakehome`): `defaults-guard` reads a
literal `/home/` as a machine home, and a test that builds a synthetic home had been tripping it whenever
the file was judged directly. The fixture is the same; only its name stopped spelling an absolute path.

## Proof

```text
$ bash bin/seat/tests/test_everything_up.sh
ok   a moved tree is written to the daily log, Runes and the well (agent road)
ok   nothing behind, nothing moved: no record, no noise (agent road)
ok   a moved tree is written to the daily log, Runes and the well (script road)
ok   nothing behind, nothing moved: no record, no noise (script road)
30 passed, 0 failed
```

## Files

- `bin/seat/tests/test_everything_up.sh`

## CHANGE LOG

- 2026-11-14 — written with the mend; the test names its road and the shipped road gets its own case.

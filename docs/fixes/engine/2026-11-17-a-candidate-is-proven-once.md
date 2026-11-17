# A candidate is proven once — the heart flips a proof, it does not re-earn it every quarter hour

**Date:** 2026-11-17 · **Component:** engine (`bin/engine/update-loop.sh`,
`bin/engine/release-lib.sh`) · **Errand:** `heart-update-loop` (plan 002 §6.2 and §8)

## What was wrong

The update loop ran the whole gate suite on the heart every fifteen minutes, failed at
`PROVE,FAIL` on the same candidate `abd366869e90`, and started again a quarter hour later. Measured
from the heart's own journal on 2026-11-17:

```
13:40:06  LOOK,moved,unset -> abd366869e90
13:46:34  PROVE,FAIL,red candidate kept for inspection
          Consumed 6min 6.841s CPU time.
13:55:05  Starting ymir-update-loop.service
14:01:08  PROVE,FAIL,red candidate kept for inspection
          Consumed 5min 43.996s CPU time.
14:10:06  Starting ymir-update-loop.service
```

Three faults held each other up:

1. **Nothing was ever current.** `~/ymir-current` did not exist, so `release_current` answered nothing,
   the loop read `LOOK,moved,unset -> abd366869e90` on every pass, and "nothing to do" (which is decided
   by comparing the running release with main) could never fire.
2. **The prove ran inside the release directory.** `~/ymir-releases/abd366869e90` is a release, not a
   checkout: it carries no `.git`. So `bin/gates/inventory.sh` failed on
   `'git' 'ls-files' '--stage' '-z'` (exit 128) and `plan-audit` failed on 356 gaps with no baseline.
   The suite was therefore red on this machine for a reason that had nothing to do with the commit.
3. **Nothing recorded that the sha had been measured.** A proof is a fact about a *commit*; measuring it
   again on the machine that must not build teaches nobody anything and costs 6 minutes of CPU on a box
   whose swap was already 3.0 of 4.0 GB.

## What was built

`bin/engine/release-lib.sh` now owns a **proof ledger** beside the release log
(`$YMIR_PROOFS_DIR`, default `~/.local/state/ymir/proofs`, configurable from
`<home>/config/releases.env`). One record per candidate sha, `key=value` lines plus a `digest=` over
them, so a proof written **elsewhere** is *verified*, not trusted: an edited record fails its digest and
is treated as no proof at all.

`bin/engine/update-loop.sh` gained three verbs and a new order of work:

| verb | answer |
|---|---|
| `decide [<sha|ref>]` | what the loop would DO with that candidate, and why — `up-to-date` · `already-proven` · `already-proven-fail` · `prove-once` |
| `proof [<sha|ref>]` | the record for that sha, verified, field by field |
| `proof-record <sha|ref> --result pass\|fail [--source L] [--detail T]` | record a proof taken **elsewhere** — the forge, or the machine that built it |
| `prove [<sha|ref>] [--force]` | prove it here, once, and record what was measured |

The run pass reads the ledger **before any heavy work**:

- **passing record** → `PROVE,already-proven` and the loop **flips the release**; nothing is proved here;
- **failing record** → `PROVE,already-proven,fail` → `HOLD`, exit 4, and **no build and no suite at all**
  for that sha, ever again. The record says when and by whom it was measured; `prove --force` re-proves
  on purpose, which is a person's decision and not a clock's;
- **no record** → `PROVE,once`: the suite runs **once**, in a **git checkout** of that commit (the tree
  itself when it stands there, otherwise a throwaway linked worktree — never a release directory), and the
  outcome is written to the ledger whether it passes or fails.

## The proof

On the heart itself, 2026-11-17. The record carries the machine's own measurement of the candidate
(13:46 and 14:01 EET, the suite that ran inside the release), and from then on a pass costs 2.3 seconds
and no heavy job:

```
$ bin/engine/update-loop.sh decide abd366869e90
decide[1]{candidate,running,verdict,why}:
  "abd366869e90","unset","already-proven-fail","proven 2026-11-17T12:23:33Z by the heart itself …: fail …"
detail,hold,abd366869e90 is proven RED; it is not proven again for this sha — re-prove on purpose with: bin/engine/update-loop.sh prove abd366869e90 --force

$ time bin/engine/update-loop.sh run
LOOK,moved,unset -> abd366869e90
PROVE,already-proven,fail abd366869e90
HOLD,main is not proven,abd366869e90 — proven once at 2026-11-17T12:23:33Z; nothing heavy ran, and it is not proven again for this sha
real	0m2.266s
```

And the whole behaviour, both halves, is a test: `bin/engine/tests/test_update_loop_proof.sh`
(gate `update-loop-proof`, 16 assertions) — the first pass proves once and records it; the second prints
`PROVE,already-proven,fail`, runs the suite **zero** further times, builds nothing and holds with exit 4;
a **pass** proof written by another machine makes the heart flip without proving at all; `decide` names
the verdict; a record edited after the fact fails its digest.

```
update-loop proof: 16 passed, 0 failed
```

## What is still owed, said plainly

The heart's `main` is still **red**: `plan-audit` wants a baseline (`bin/gates/plan-audit.sh --baseline`),
and `inventory` is only red when the suite is run from a release instead of a checkout — which this change
stops doing. Recording the proof stops the *repeat*, which is what this errand was for; it does not make a
red commit green. The flip itself needs a passing proof, and a passing proof is now something a builder can
publish once — `bin/engine/update-loop.sh proof-record <sha> --result pass --source forge-builder`.

The heart's unit still executes `~/ymir/bin/engine/update-loop.sh`, the heart's own checkout of `main`.
Until this change lands on `main` and that checkout is fast-forwarded, the old code keeps proving every
quarter hour; the proof record planted on the machine means the first pass after the update holds quietly.

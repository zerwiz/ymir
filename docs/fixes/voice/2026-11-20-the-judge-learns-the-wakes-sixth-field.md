# The judge learns the wake's sixth field

**Date:** 2026-11-20 · **Component:** voice · **Gate:** `voice-arm` ·
**Test:** `bin/voice/tests/test_rodd_arm.sh` ·
**Caused by:** `f0e495e1` *"wake queue: the arm hears people first (plan 328)"*, gathered as `280107cc`

## What was wrong

The whole-tree gate on main was red from 2026-11-19 22:46 CET (run 44631675501, head `0d14a4d6`). Exactly one row
failed — `voice-arm`, *"Rödd knocks on the arm, and refuses when nobody is holding it (plan 223)"* — and the test
printed **70 passed, 1 failed**. The run before it (`3354412b`) was green.

The failing assertion was named, not guessed:

```
FAIL the message's tabs did not become fields
     1795140001^I1^Isignal^Irodd-1795140001^IRM-CM-6dd (the voice) to the arm holder: hand this on with a tab^Iclass=voice
```

That line has six tab-separated fields; the test demanded exactly five.

**The code was right and the judge was stale.** Plan 328 taught each door that files a wake to name its class as a
**trailing** `class=<voice|ask|report>` field, and it says plainly why it is trailing — *"the field is trailing so
every reader that matches from the head of the line is unmoved"*. The same commit updated the door's own
`--self-test` in `bin/voice/rodd-arm.sh` to read `cut -f6`, and documented the new shape in
`docs/features/rodd-the-voice.md`. It did not touch `bin/voice/tests/test_rodd_arm.sh` — the independent judge, the
file whose whole purpose is to catch a door that lies to itself.

So the door and its self-test agreed with each other and both disagreed with the judge. That is exactly the drift
the judge exists to catch, and it caught it.

The two commits named as suspects in the brief were read and are innocent: `8751c468` changed role resolution, and
`3aad3846` added `--attach-only` to the arm hook. Neither touches the wake line's field count.

## What was forged

Only the test changed; no shipped behaviour was touched, no assertion was weakened, and the row was not skipped.

- The field count assertion now reads **six**, and says why in a comment: five fields as always, plus plan 328's
  trailing class.
- The tab-proof is now stated **exactly** rather than loosely: field 5 must equal the whole flattened payload,
  `Rödd (the voice) to the arm holder: hand this on with a tab`. A tab or newline that had become a field would
  shift this check and the count above it. This is stronger than the previous substring match, not weaker.
- A new assertion: the class field is well-formed and last — one of `class=voice`, `class=ask`, `class=report`.
- A new assertion: a tell from Rödd is `class=voice`, which is the class the door's own `tell_class` must choose for
  the voice.

The count of assertions grew from 71 to 73. None was removed, relaxed, or skipped.

## Proof (measured)

```
bash bin/voice/tests/test_rodd_arm.sh                    → test_rodd_arm: 73 passed, 0 failed
YMIR_GATE_CHECK_DIR=/tmp/gate-one bash bin/gates/ci-verify.sh
                                                          → "voice-arm","PASS"
```

Whole-tree, on this worktree, before and after the change — the same command, so the comparison is honest:

| tree | FAIL rows from `ci-verify.sh --fast` |
|---|---|
| pristine `0d14a4d6` (my change stashed) | **9**, including `voice-arm` |
| this branch | **8** — `voice-arm` is gone, no new row is red |

The other eight rows (`queue`, `plan-ledger`, `review-seat-keeper`, `portability`, `weave`, `ext-api`, `ext-smoke`,
`nornir-day-gate`) fail identically on the pristine tree. They are local artifacts of running the suite from a seat
worktree without `YMIR_ROOT` and the home's state — the CI runner reported the `voice-arm` row and no other. They are
not this change's and were left alone.

## What this teaches

A contract change belongs to **both** its door and its judge. When plan 328 moved the wake shape, the door was told
and the judge was not, so a green door and a red gate were the same fact. The judge file is where a shape is pinned;
a change that alters a shape must open it in the same commit.

## Records

- `bin/voice/tests/test_rodd_arm.sh` — the judge, corrected to the six-field contract.
- This note. No plan or board was updated: plan 328 already owns the contract, and this change restores the proof of
  it rather than altering it.

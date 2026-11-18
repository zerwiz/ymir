# The plans became data, and his list can stop lying about its age

**Date:** 2026-11-15 · **Component:** records · **Plan:** 298, phases 1–2

## Why

Plan 298 opened on the Allfather's words: *"I need a system thats in the registry that keeps my
peronal todolist up to date with what plans are not done yet."*

The fault was measured, not guessed. Every input the answer needs was already written down — the
plans, their headers, `register.md`, and `hodd/identity/projects.yaml` naming each shelf — and
**nothing joined them**. `bin/day/day.sh` read the plans only as a privacy category. So the measured
half of his list was typed by hand, stamped `as_of 2026-11-11`, and had been quietly lying about what
was still open on every day since.

Measured on the real ledger while building this:

```
$ bin/records/plans-state.sh --check
plans-state: ymir-platform: plan number 202 is used by 2 files (202-cloudroom-on-the-heart.md, 202-the-red-range.md)
…
plans-state check: 22 finding(s)
```

and before the door existed, **0 of 264** plans in ymir's own shelf carried a readable state.

## What was built

`bin/records/plans-state.sh` (with `bin/records/plans_state.py` as its engine, one truth shared with
the day door) reads every shelf the registry names and answers, per plan, whether it is done and what
proves it. `bin/day/day.sh plans` is the read.

Two rules it is built on, both taken from the merge gate:

- **a state it cannot measure is `open`, never `done`** — silence is not finished work;
- **nothing is done without a witness**, and the witness is carried in the answer.

## The four witnesses

| Witness | How the door reads it |
|---|---|
| the header | `state: done`, or the older `Status: done` |
| the register | a `register.md` row with a `done` word that names the plan |
| the folder | a plan filed under `done/` on a shelf whose layout says the folder is the state |
| a merged PR | `PR #N` or `pull/N` in the plan, and `gh pr view --json state` says MERGED (`--with-prs`) |

## What a zero must never stand for

Three findings shaped the reader, and each is a case in `tests/test_plans_state.sh`:

- **A named shelf that is not there is `ABSENT` with its path**, never an empty shelf. An empty shelf
  and a missing one are different facts; a second project's ledger is not cloned on this machine,
  and the door says so — naming its path — rather than reporting zero plans.
- **A dated name is a report, not a plan.** `2026-11-05-report.md` and the thirteen
  `20261105T00NNZ-…` errand reports would otherwise have been filed as open work, and one of them as
  "plan 2026".
- **A template is not work.** `bug-0000-short-description.md` and `_templates/` are shapes to copy;
  number zero is never a real plan.

## What it found in the house, which nobody had counted

- **95 retired reference plans** under `old-plans/` — counted, never listed as debt.
- **16 dated session reports** on the shelves, now correctly not plans.
- **22 colliding plan numbers**, exactly the duplicates plan 298 §6 lists (93, 94, 199, 200, 201, 202,
  204, 206, 210, 212, 219) plus 72, 86, 232, 255, 275, 286. The door reports them; renumbering is
  still his decision.
- **6 plans on one project's shelf were already done** — filed under `tickets/done/` — and would have
  been carried as open work forever by a reader that only looked at headers.

## Proof

```
$ bash tests/test_plans_state.sh
ok   a plan declaring nothing is open
ok   a `state: done` header closes a plan
ok   a register row saying done closes a plan
ok   a plan filed under done/ is done by the shelf's word
ok   a PR nobody asked about leaves its plan open
ok   no plan is called done without a witness
ok   a named shelf that is missing is reported absent, never counted as empty
ok   --with-prs closes the plan whose PR merged, carrying the PR as proof
plans-state: every case held
```

The merged-PR case runs offline against a stub `gh` on `PATH`, so the suite needs no account and no
network.

## What this change does not do

Phases 3–6 of plan 298 — the markers inside `todo.md`, `--write-derived`, the tick as a proposal, the
`--check-age` cron gate and the Eir surface — are **not** here. This change makes the plans
measurable; it does not yet write them into his list, and it edits nothing above the derived-half
boundary because there is no derived half to edit yet.

## CHANGE LOG

- 2026-11-18 — review-mend: added missing heading for #817

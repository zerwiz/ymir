# The plan board — what is done, what is not, and what was replaced

## What it is

One command that answers three questions about the plan ledger: **how many plans are done and not done**, **what to
work on next**, and **which old plans a newer one has superseded**. It reads evidence, not labels: the index's status
column had said "opened" for plans long since shipped, so a label nobody updates cannot answer.

For every plan it gathers:

- the plan's own declared header (`status:`), if it has one — that is a fact, and wins;
- merged pull requests whose **title or branch** names the plan (the strong evidence);
- commits on `main` and fix notes in `docs/fixes/` that name it;
- the `PR #N` numbers the plan cites, and whether each merged;
- a **newer** plan that says it supersedes, replaces, retires or absorbs this one.

From that it **suggests** a status, marked with `?` — `done?`, `building?`, `superseded?`. A suggestion is never a
verdict. You read it, and `confirm` writes the real status into the plan's header.

## What you need

The home (`$YMIR_HOME`) with its plan ledger; `gh` signed in, for the pull-request evidence (without it the board still
runs on commits and fix notes). `YMIR_PLAN_DIR` points it at another shelf.

## The commands

```bash
bin/records/plan-board.sh tally                  # done · building · open · parked · superseded, and how many are unconfirmed
bin/records/plan-board.sh next 10                # what to work on: building first, then open, newest first
bin/records/plan-board.sh supersede              # old plans a newer one claims to replace — to validate
bin/records/plan-board.sh show 81                # the evidence for one plan
bin/records/plan-board.sh list --status open     # every plan in one state
bin/records/plan-board.sh confirm 81 superseded --by 212   # make it a fact: writes the header of 81 (and 212's supersedes)
bin/records/plan-board.sh confirm 233 done
```

Add `--json` to `tally`, `list`, `next` and `supersede` for machine output.

**The loop:** `tally` to see the shape · `supersede` and confirm or dismiss each claim · `list --status done` and
confirm the true ones · `next` to choose the work.

## Limits

- **A shared number shares its evidence.** Two files called `212-…` both get every PR and commit that names "plan 212".
  `tally` lists the shared numbers; `confirm` refuses to guess which of two files a `supersedes` line belongs in.
- **Evidence is not proof.** A merged PR that names a plan may have built one phase of six. That is why every
  suggestion carries a `?` until a person confirms it.
- It reads the top of the shelf only: `old-plans/`, `inbox/`, `audits/` and `errands/` are records about plans.

## If it does not work

- `plan-board: no ledger` — the home did not answer (`bin/vault/hodd.sh path`); set `YMIR_PLAN_DIR`.
- Every plan reads `open` — `gh` is not signed in and the commits name no plans; run `gh auth status`.

## CHANGE LOG

- **2026-11-12** — Written. The Allfather: *"we need a system to track how many plans we have done and not done and
  what we need to work on so we can work on it and validate if old plans are superseded."*

# The plan board reads evidence, not labels

**Date:** 2026-11-12 · **Component:** records

## The fault

Nothing could say how many plans were done. `bin/records/plan-state.sh audit` read a `Status:` header that 218 of
229 files did not carry, and tallied `done=0 open=1`. The index's status column said "opened" for 121 plans, many long
since shipped. The day's hand audit (`plans/audits/2026-11-12-plan-status-audit.md` in the home) measured the truth
once; nothing could measure it again.

## The change

`bin/records/plan-board.sh` — `tally · list · next · supersede · show · confirm`. It suggests a status from merged PRs
naming the plan (title or branch), commits, fix notes, and the PRs the plan cites; it reads a negation ("nothing
built") before a keyword, which the board sync did not; it finds old plans a newer one claims to supersede. `confirm`
writes the house's declared header (`bin/records/header.sh`'s schema: `status · verified · verified_by · supersedes ·
superseded_by`) in front matter, never the body.

## Proof

On the live ledger: 214 plans counted, matching the hand audit. `confirm 81 superseded --by 212` on a scratch copy
wrote the front matter, and `show 81` then reported `status: superseded`, `why: header`.

## CHANGE LOG

- **2026-11-12** — note written with the door.

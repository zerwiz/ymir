# The far halls is plan 210 — a number claimed twice in one hour

**Date:** 2026-11-06 · **Follows:** `docs/fixes/forge/2026-11-06-the-far-halls-read-every-repo.md` · **Component:** forge

## What happened

The plan behind PR #558 was written and numbered **207** because the index's highest plan at that moment
was 206. In the same minutes another hand claimed **207** ("the day's surface") and its commit reached
`svartalfaheim/whynotproductions/projects/ymir/plans/` first, followed by **208** and **209**. Two plans
carried one number in the ledger — the exact collision `RULES/06` and the ledger's own conventions forbid.

## What was done

- The plan moved to **`plans/210-the-far-halls.md`** — the later claim is the one that moves; an earlier
  hand's record is never rewritten to make room.
- Its head now carries the collision, in the plan itself, so the next hand reads why 210 exists and 207
  does not point at this work.
- Every reference in the code and the asset was corrected in the same pass: `bin/forge/intake.py`,
  `bin/forge/mjollnir.sh`, `bin/agents/project-git.sh`, `bin/gates/tests/test_mjollnir_intake.sh`,
  `.agents/skills/galdr-ymirsystem/assets/mjollnir.md`.
- The earlier fix note keeps its text and gains a dated **Correction** section — a note is never rewritten.
- The ledger index keeps the other hand's 206–209 rows and appends 210.

## The lesson, stated so it costs once

**A plan number is claimed before the document is written, not after.** Reading "the highest in the
index" is a claim made by observation, and observation races. The claim must be a write that cannot
succeed twice — `bin/records/plan.sh next` printing a number is only half of it; the reservation has to
land in the ledger (or an explicit claim file) before the body is authored.

## Files

- `$YMIR_HOME/svartalfaheim/whynotproductions/projects/ymir/plans/210-the-far-halls.md` (renamed from `207-…`)
- `$YMIR_HOME/svartalfaheim/whynotproductions/projects/ymir/plans/README.md` (both hands' rows kept)
- `bin/forge/intake.py` · `bin/forge/mjollnir.sh` · `bin/agents/project-git.sh`
- `bin/gates/tests/test_mjollnir_intake.sh` · `.agents/skills/galdr-ymirsystem/assets/mjollnir.md`
- `docs/fixes/forge/2026-11-06-the-far-halls-read-every-repo.md` (correction section appended)

## CHANGE LOG

- **2026-11-06** — written when the push was refused for carrying no new note in its range, which is the
  gate behaving exactly as designed: a push that changes the record carries the record.

## gate · 2026-11-03 — the hook and the guard disagreed, and the hook was right in form

### Why
While pushing PR #493's branch, the pre-push hook refused *"no fix note in this
range"* on a commit whose only change was **editing an existing note**. The guard
counts a note only when it is **added** in the range (`--diff-filter=A`), so a
correction to a note already pushed is a change that owes a new note — which is the
house's own law (Rule 06: a correction is a new entry, not an edit).

### Mend
- The record of the disagreement (and of the merge-range fix that preceded it) is
  written as **its own new note**, so the range carries an added note again.
- The two real fixes it documents:
  1. a merge is not a change — the guard now judges `git log --no-merges` paths, so a
     branch that took main in is not asked to write notes for main's history;
  2. the component map learned the branch's own paths (`bin/gates/registers.sh`,
     `bin/gates/guards.sh`, `bin/gates/tests/*`, `FEATURES.md`, `docs/features/*`,
     and the three derived registers) — a path with no component cannot be covered.

### Proven
- `fixes-guard --check` on the branch: *ok — 3 note(s), and the record speaks to the
  change*.
- The register door's own wards: registers current (inventory · capabilities), the
  woven catalogue current, its row seated as a fragment.

## CHANGE LOG

- **2026-11-09** — the note was carried into the integration branch whole, its history with it.

## gates · unversioned · 2026-11-06 — the row is not the register: a hand-merge of a generated file

PR 536 (`integrate/night-2026-11-06`) conflicted with `main` in exactly two files —
`.agents/assets/agents/capabilities.md` and `bin/README.md`. Both are **generated**
registers, and both sides had legitimately written them: the branch recorded the
night's doors (`eindri-checkpoint.sh`, `factory-new.sh`, `factory-check.sh`,
`audit-apply.sh`, …) and `main` recorded its own (`review-rules.sh`,
`model-rows-guard.sh`, `pr-ship-guard.sh`, `test_handoff_packet.sh`, …).

The merge was resolved on the web, by taking the rows from both sides. That is the
right *intent* and the wrong *method*, and the register proved it: the rows were
present, but the header an aggregate carries — `capabilities[5]{shell doors: 748}`
and `bin[783]` — still counted one side only. Measured at the merge commit,
`bin/gates/registers.sh check` returned **STALE for both generators**, which is
what the `ward` and `compliance` rows in CI were reporting.

A generated file is not resolved by choosing rows; it is resolved by **running its
generator over the merged tree**. `bin/gates/registers.sh generate` — the one door
for every generated register — rewrote both files, and the honest union appears:
`capabilities[5]{shell doors: 754}` and `bin[789]`, with every door from both sides
named. The 928 touched lines in `capabilities.md` are the sorted row order being
restored: a hand-inserted row sits where it was typed, not where the register keeps
it.

`registers.sh check` now reports `inventory.sh` **current** and `capabilities.sh`
**current**. Nothing is hand-edited and nothing is exempted; `registers-guard` and
`inventory-guard` read the generated files, so they agree by construction.

Why it matters twice over: the previous entry in this directory was the same fault
from the other side — a register that named a file the tree did not ship. A register
is only worth its gate if the tree writes it, never a person.

## CHANGE LOG

- 2026-11-06 · `main` merged into `integrate/night-2026-11-06`; the web merge kept the
  rows but not the counts; both registers regenerated through
  `bin/gates/registers.sh generate`; `check` → current for both generators.

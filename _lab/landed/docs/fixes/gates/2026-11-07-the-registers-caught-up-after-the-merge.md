## gates · unversioned · 2026-11-07 — the registers caught up after the conflict merge

Branch `fix/the-door-names-its-road-and-its-register` merged `origin/main` cleanly, then
`inventory-guard` and `registers-guard` went red — `main_baseline[]` said the inventory guard was
**this branch's** to fix and the registers guard was red on main too.

Both are one fault: the generated registers (`bin/README.md`, `.agents/assets/agents/capabilities.md`,
`bin/gates/inventory.sh`, `bin/gates/capabilities.sh`) were stale against the merged tree. They were
regenerated — never hand-edited — and the wards were re-run: **28 PASS, 0 FAIL**.

## CHANGE LOG

- 2026-11-07 · registers regenerated after the merge; nothing hand-edited.

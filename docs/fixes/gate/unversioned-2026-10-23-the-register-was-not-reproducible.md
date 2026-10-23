## gate · unversioned · 2026-10-23 — the register counted itself, so its own `--check` was a lottery

### Why

`bin/gates/inventory.sh` renders `bin/README.md` and `.agents/backend/README.md` — and its
`callers` column is derived by scanning every tracked door in `bin/` for the door's **name**. That
scan included **`bin/README.md` itself**, the file it was writing. So the moment the index listed a
door, that door gained one caller; the next render counted one more. Measured on a clean worktree:

```
render 1  →  97 lines changed
render 2  →  26 lines changed
--check   →  current
```

It never settled in one write, and the number of passes was not bounded — it depended on how many
rows had changed. `--check` therefore could not be trusted on a correct tree, which is why nobody put
it in the ward list: **the gate was absent because it would have lied.**

Two mends, in the order the fault happened:

1. **A view is not a caller.** No `README.md` is counted as a caller of anything. A markdown page that
   NAMES a door does not CALL it. After the change: `render 1 → 0`, `render 2 → 0`, `--check` current
   (573 files, 175 backend). The register is now derived **and** reproducible — the property its own
   header comment demanded ("or its `--check` is a lottery") and did not have.
2. **The check is now a ward.** `bin/gates/guards/inventory-guard.sh` runs `inventory.sh --check` and
   carries the generator's own message up; it is seeded into `bin/gates/guards.sh`'s ONE ward list
   (13 → 14). A gate that runs nowhere is a capability silently absent — this one runs on every push.

Same day, the same fault one shelf over: `apps/` holds **405** entry points and `tools/` **11 of 13**
in no register at all, because the inventory only ever walked `bin/` and the backend shelf.
`bin/gates/doors.sh --root <dir>` renders the same door shape for **any** directory (`*/DOORS.md`),
tracked-only so it is reproducible from a clean checkout, with `--check` for the gate. Measured:
`tools/` 13 rows · `apps/odrerir` 12 · `hodd/bin` 8 · `--check` clean on a second render.

### Files
- `bin/gates/inventory.sh` — the caller scan excludes views
- `bin/gates/guards/inventory-guard.sh` — new ward
- `bin/gates/guards.sh` — the ward list (13 → 14)
- `bin/gates/doors.sh` + `src/ymir_runtime/doors.py` — the scoped register (plan 115 P7/P8)
- `bin/README.md`, `.agents/backend/README.md` — regenerated
- `docs/fixes/gate/unversioned-2026-10-23-the-register-was-not-reproducible.md`

### Verified
```
bin/gates/inventory.sh            render twice → 0 lines changed; --check current (573 files)
bin/gates/inventory.sh --check    bin current · backend current
bin/gates/doors.sh --root tools   "13" rows; --check on a second render → current
bin/gates/guards.sh               14 wards, all PASS
```
One honest note: `bin/seat/valknut-load.sh --check` FAILS inside a **fresh worktree** ("pi settings
name the extensions tree") because the harness is registered to the main tree. It passes in the main
tree; it is a worktree property, not a regression, and CI checks the tree it builds.

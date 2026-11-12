## gates · unversioned · 2026-11-12 — the folder indexes name the new update doors

### Why

Plan 278 added `bin/agents/groa-verdict-lib.sh`, `bin/agents/surfaces.py` and three tests, and changed the
caller counts and line counts of Eir, Gróa and the unit writer. The generated folder indexes (`bin/*/INDEX.md`)
are re-derived from the tree, so they were one step behind the change.

### What changed

`bin/gates/inventory.sh` was run and its output committed. The same run also caught rows on main that were
already behind (a new clock script, a few caller counts). No index was edited by hand.

### Proof

`bin/gates/guards/inventory-guard.sh` and `bin/gates/guards/registers-guard.sh` report every register current.

### Files

- `bin/agents/INDEX.md`
- `bin/engine/INDEX.md`
- `bin/forge/INDEX.md`
- `bin/mail/INDEX.md`
- `bin/records/INDEX.md`
- `bin/time/INDEX.md`
- `bin/vault/INDEX.md`
- `bin/voice/INDEX.md`

## CHANGE LOG

- **2026-11-12** — Opened.

## agents · 2026-10-23 — the surface rule is 37, not 34: a number is claimed once

### Files
- `RULES/37-a-surface-may-not-show-what-it-did-not-receive.md` (renamed from 34)
- `RULES/README.md` (index row and the TOON block)
- `docs/fixes/agents/2026-10-23-a-surface-may-not-show-what-it-did-not-receive.md`, `.agents/skills/galdr-ymirsystem/assets/smidja.md`
- `bin/README.md`, `.agents/backend/README.md` (regenerated — stale again after main grew four doors)

### Why
Rule 34/35 (the library of records) and Rule 36 (the run is visible) are claimed by the open library change.
Two rules numbered 34 in one tree is the fault `rules-number-guard` exists to refuse, so this branch's rule
moved to the next free number — **37** — and every citation moved with it: the index, the fix note, and the
smidja asset that tells the factory what it owes the surface it ships.

The door register is regenerated in the same commit; `inventory --check` now reports **current (596 files)**
and the ward set passes with **0 FAIL**, because the generator no longer reads its own output (the feedback
loop fixed an hour earlier) — two consecutive runs differ by **0 lines**.

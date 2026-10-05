## runtime · unversioned · 2026-09-27 — the wards: the maps made true (plan 58 Phase 8)

### Why
Plan 58's phases each deepened the tree, but the maps did not follow. `STRUCTURE.md`
carried a `bin/` count that no longer matched the folder it describes, the live
architecture (the python engine, the fleet topology, the report-shelf handoff, the
role-gated schedule) lived only in the plan, and two long-standing compliance notes
(naming `fm-*`, mocks `fm-composer-lib`) were carried as debts with no owner and no
declared scope. A map that lies is worse than no map: the next agent trusts it.
This pass draws the maps true against the live tree, resolves the two gate notes by
declaring the ward's scope once, and records the whole in one note.

### What
**`STRUCTURE.md` — the counts re-measured, never trusted.**
- `bin/` corrected to the live **214** files (was 213; the tree advanced after the
  last count). Counted with `ls -A bin | wc -l`.
- `state/` is now stated as what it is: a **symlink → `$YMIR_HOME/state`** (Rule 04,
  one truth, never a tree copy) — in the tree and in the Directory-intent table.
- `.pi/mcp-adapter.json` naming reflected post-#214: the tracked file is
  `.pi/mcp-adapter.json.example`; the rendered `.pi/mcp-adapter.json` is git-ignored.
- `src/ymir_runtime/` engine added to the listing (`__init__.py · __main__.py`
  alongside the four verbs).

**`docs/Architecture.md` — the plan's own architecture, drawn true.**
Appended **Appendix A — The live architecture, drawn true (2026-09-27)**, and a
live-shape note at the top making the appendix authoritative where the draft is
stale. The appendix records: the engine (`src/ymir_runtime/` four verbs, the
strangler doors, what it does not own yet), the gateway (ports, the record MCP
doors, the `.pi/mcp-adapter.json` bind, the `a2abridge` mesh), the report-shelf
handoff (status line + `$STATE/eindri-reports/<id>.md`, the failsafe's scope, the
fourth failure mode), role-gated crons (`@heart`/`@forge`, both orders, roles from
`bin/fleet/topology.sh` / `fleet.json`), the topology (heart on zerwizserver, plan 51
Part 7), and four corrections to the stale draft (single tenant, SQLite/engram,
plans in the hoard, the Rut port deferred).

**The two standing compliance notes — resolved, not silenced.**
- **naming (`fm-*`).** The gate's subject is the shipped door surface (`AGENTS.md`
  + `bin/*.sh`); the upstream `fm-*` provenance lives at `.agents/backend/` (measured:
  `bin/fm-*` = 0, `.agents/backend/fm-*` = 163). The declaration is recorded in the
  owning asset (`.agents/skills/galdr-ymirsystem/assets/runtime-compliance.md`, G4)
  and in the harness asset's provenance section. **Owner:** Galdr.
- **mocks (`fm-composer-lib.sh`).** The classifier's signature trailing comment —
  the only code-line hit in the provenance tree — now sits on its own comment lines
  above the function, so the code line reads as behaviour, not as a design note. The
  ward's scope and owner are recorded in `runtime-compliance.md` (G8). **Owner:** Galdr.

**The governed assets, in the same change.**
- `.agents/skills/galdr-ymirsystem/assets/runtime-compliance.md` — the `governed[]`
  mirror synced to `AGENTS.md`'s ten rows (was six), plus the G4/G8 scope declarations.
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` — §12
  provenance: where the `fm-*` record lives and where the wards look.
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md` — §6 the role-gated
  schedule; §7 the report-shelf handoff contract.

### Files
- `STRUCTURE.md`
- `docs/Architecture.md`
- `.agents/skills/galdr-ymirsystem/assets/runtime-compliance.md`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`
- `.agents/backend/fm-composer-lib.sh` (one comment reflow, no behaviour change)

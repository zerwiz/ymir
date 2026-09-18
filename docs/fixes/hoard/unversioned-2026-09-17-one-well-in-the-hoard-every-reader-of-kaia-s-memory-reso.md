## hoard · unversioned · 2026-09-17 — one well, in the hoard: every reader of Kaia's memory resolves the hoard store

### Why
- **The memory is ONE store and it lives in the hoard** —
  `$YMIR_HOME/hodd/memory/kaia.engram` — never in the tree, never in a
  migrated copy. `bin/hoard-lib.sh` gains `hoard_memory_store` (the one
  resolver); every reader honors it or an explicit `ENGRAM_DB`:
  `mimir-bridge.sh`/`mimir-bridge.py`, `mimir-reflect.sh`, `a2a-mcp.sh`,
  `ymir-install.sh` step_memory, and the rendered `.pi/mcp.json.example`
  (`__YMIR_HOME__/hodd/memory/kaia.engram`).
- **The duplicate is dead.** The old store (`$YMIR_HOME/memory/kaia.engram`,
  plus the migration seed copy) is struck from this machine and the vault;
  its 8 episodes were seeded into the hoard store first. The public ymir
  repo's `.agents/memory/kaia.engram*` leftovers are deleted (already guarded
  by `.gitignore`) and the 0003 migration now copies INTO the hoard.
- The Allfather's decision, accepted and recorded everywhere: the well must
  travel between his computers, so it rides the private vault as one store.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/memory-well.md` — the
Store row, MCP command, law #4, and the Python recipe now name the hoard path.

### Files
- *(carried from the frozen CHANGELOG.md)*

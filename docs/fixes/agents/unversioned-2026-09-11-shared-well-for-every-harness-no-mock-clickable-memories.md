## agents · unversioned · 2026-09-11 — Shared well for every harness; no mock; clickable memories

### Why
- **Harnesses:** the engram MCP server is now registered for all four OpenCode
  accounts (`opencode`, `opencode-rd`, `opencode-work`, `opencode-oczer`), Pi
  (`~/.pi/agent/settings.json` + `mcp.json` + `.pi/mcp.json`), Claude, Cursor,
  and Codex. Registered **unscoped** so every harness reads the one shared well
  (per-call `agent_id` still attributes writes).
- **No mock:** purged every test/mock episode (`smoke`/`Test observation`) from
  both the engram store and `episodes.jsonl` → 367 true episodes. Test writes
  never enter the well.
- **UI:** Well memories are now **clickable** — `GET /api/well/episode?id=` and
  a bridge `/episode` endpoint feed a modal with the full memory text.
- **Bridge fix:** `/recent` and `/recall` restored; added `/episode`.
- **Lifecycle fix:** `bifrost-bridge.sh` / `mimir-bridge.sh` now stop by process
  match when the PID file is missing, and record the PID when the port is
  already up — so `scripts/stop.sh` truly lowers the whole system and
  `scripts/start.sh` truly raises it.
- **Galdr:** new asset `.agents/skills/galdr-ymirsystem/assets/memory-well.md` (store,
  bridge, MCP, harness matrix, laws, verify), routed in `SKILL.md`; registry +
  harness README updated; mirrored to tyr.
- **Verified:** MCP recall 1.0 / stats 367, full stop→start cycle (3888/3889/
  4602/4603/8437), compliance 8/8, smoke 8/8.

### Files
- *(carried from the frozen CHANGELOG.md)*

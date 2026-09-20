## runtime · unversioned · 2026-09-11 — The well is real (Mimirsbrunn / engram)

### Why
- **New:** `bin/mimir-bridge.py` + `bin/mimir-bridge.sh` — the `:4602` HTTP face
  the supervision tree named but that upstream never shipped (engram exposes a
  CLI + MCP server only). Endpoints: `/health`, `/recall`, `/recent`,
  `/timeline`, `/inspect`, `/observe`.
- **New:** repo-local store `.agents/memory/kaia.engram`, seeded from the
  368-episode JSONL well.
- **Wired:** gate API `/api/well` now does semantic recall via the bridge (local
  file fallback) and `/api/mimir/health` is live; the Well gate's Bridge tile
  and timeline read real data (mock removed).
- **Harnesses:** the engram MCP server is registered for OpenCode, Pi, Claude,
  Cursor, and Codex; requires the `mcp<2` SDK (`engram-mcp` breaks on mcp 2.x).
- **Lifecycle:** the bridge is raised by `scripts/start.sh` and
  `bin/saga-session-start.sh`; the stale `engram.server` command was corrected.
- **Verified:** bridge up (370 episodes), semantic recall, MCP handshake
  (engram 1.30), compliance 8/8, smoke 8/8.

### Files
- *(carried from the frozen CHANGELOG.md)*

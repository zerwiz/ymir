## runtime · unversioned · 2026-09-25 — the harnesses drank a broken well, and OpenCode lost the mesh in a worktree

### Why
The Allfather asked whether Pi and OpenCode were set up to function with the mesh.
They were — live proof: `opencode mcp list` showed `a2abridge connected`. But two
adjacent faults meant memory and mesh were only half-reachable.

- **The stdio `engram` MCP was dead in BOTH harnesses.** `bin/a2a-mcp.sh` wired
  `$HOME/.local/bin/engram-mcp`, whose shebang points at the uv CPython — which
  does **not** carry the `mcp` SDK:
  `ModuleNotFoundError: No module named 'mcp'`. The entry connected and closed
  (`MCP error -32000: Connection closed`). The HTTP well door (`:8317`) still
  worked, so the fault was hidden behind a duplicate that was never exercised.
  The script now **resolves a working binary** — `$ENGRAM_BIN`, then the well
  venv's `~/.fleet/well-venv/bin/engram-mcp` (built by `fleet-ensure.sh`), then
  `command -v engram-mcp` — testing each candidate's **shebang interpreter** for
  `import mcp`; it never wires a path it has not proven.
- **OpenCode's well door pointed at a LAN IP.** The global
  `~/.config/opencode/opencode.json` carried
  `http://192.168.68.111:8317/mcp` (the heart's LAN address) — connected at home,
  dead on the road. `fleet-ensure.sh`'s `wire_mcp` now writes the **seat's own**
  well door (`WELL_URL`, loopback) into that global config, not only into Pi.
- **OpenCode is project-scoped, so a worktree lost the mesh.** `a2a-mcp.sh`
  wrote `a2abridge`/`engram` only into the repo's untracked `opencode.json`;
  OpenCode run in a Yggdrasil worktree saw none of them. The installer now
  **merges the same servers into OpenCode's GLOBAL config** when wiring the
  operator's seat (never under `--project`), so a worker seated in a worktree
  still resolves the mesh and the well.
- **Templates corrected:** `.pi/mcp.json.example` and `opencode.json.example` now
  name the well venv's binary and the hoard's store (the OpenCode example had
  pointed the store at `__YMIR_ROOT__/.agents/memory/kaia.engram` — the tree, not
  the hoard).
- **Proved:** `opencode mcp list` → `well ✓ · a2abridge ✓ · engram ✓`; the engram
  MCP enumerates 9 tools (`remember_fact · search_memory · get_recent_memories ·
  …`); Pi's `mcpServers.engram` now names the venv binary.

galdr-reread: `harness-integration/README.md` §13 (the resolved engram binary and
the OpenCode global merge).

### Files
- `bin/a2a-mcp.sh`
- `bin/fleet-ensure.sh`
- `.pi/mcp.json.example`
- `opencode.json.example`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`

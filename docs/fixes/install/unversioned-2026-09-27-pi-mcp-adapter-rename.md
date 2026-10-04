## install · unversioned · 2026-09-27 — the pi MCP adapter stops auto-reading mcp.json

### Why

`pi-mcp-adapter` (the agent home's own npm package, `~/.pi/agent/npm/node_modules/pi-mcp-adapter`)
no longer auto-reads `mcp.json` — it reads `mcp-adapter.json`. At session start it
warned for both legacy candidates:

- `~/.pi/agent/mcp.json` (the global register)
- `<repo>/.pi/mcp.json` (the project register)

The machine's live configs were moved to the new names (both registrations intact:
well · bolthorn · skuld · snotra · firecrawl · hnoss · a2abridge · engram, and the
project's engram + skills). But the distro still GENERATES and probes the dead path,
so the next install, fleet raise, a2a install, mcp-gate toggle, doctor check or smoke
test would recreate `mcp.json` — a file the adapter ignores — and the warning would
return. The change aligns the whole pi-MCP surface to `mcp-adapter.json`:

- **Renderers/writers:** `bin/seat/valknut-load.sh` (renders the project register from the
  example), `bin/fleet-ensure.sh` (writes the seat's global register at raise),
  `bin/bridge/a2a-mcp.sh` (both scopes), `bin/bridge/mcp-config.sh` (global), `bin/bridge/mcp-gate.sh`
  (default target).
- **Probes/readers:** `bin/eir-doctor.sh` (hoard `mcp` surface), the lifecycle
  smoke test's MCP probe.
- **Example + ignore:** `.pi/mcp.json.example` → `.pi/mcp-adapter.json.example`
  (git mv), `.gitignore` names `mcp-adapter.json`.
- **Docs:** `README.md`, `STRUCTURE.md`, the owning Galdr assets
  (harness-integration, installation, memory-well), the ratatoskr and hnoss skill
  reads — every `pi --mcp-config .pi/mcp.json` launch word now says
  `--mcp-config .pi/mcp-adapter.json` (the flag itself is unchanged and still takes
  any path).
- The env override `PI_MCP_JSON` is untouched — it names a variable, not a path;
  only the default target changed.

Also mended locally (outside the repo, plan 42's wound shape): the project register's
`engram --db $HOME_SEAT/hodd/memory/kaia.engram` pointed at an absent store while
the well lives at `~/Documents/ymirhome/...` — re-pointed to the living store.

galdr-reread: `harness-integration/README.md`, `installation.md`, `memory-well.md`.

### Files

- `.gitignore`
- `.pi/mcp.json.example` → `.pi/mcp-adapter.json.example`
- `bin/seat/valknut-load.sh`, `bin/bridge/mcp-config.sh`, `bin/bridge/mcp-gate.sh`, `bin/bridge/a2a-mcp.sh`,
  `bin/fleet-ensure.sh`, `bin/ymir-fleet.sh`, `bin/eir-doctor.sh`
- `.agents/skills/lifecycle/smoke_test.sh`
- `README.md`, `STRUCTURE.md`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`,
  `.agents/skills/galdr-ymirsystem/assets/installation.md`,
  `.agents/skills/galdr-ymirsystem/assets/memory-well.md`
- `.agents/skills/ratatoskr-a2a/SKILL.md`, `.agents/skills/hnoss-design/DESIGN.md`
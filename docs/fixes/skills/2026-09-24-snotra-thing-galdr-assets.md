## skills · 2026-09-24 — the meeting capabilities registered in Galdr's maps

### Why
Galdr is the master builder/maintainer of the runtime, and "a runtime change not
reflected in `assets/` is an incomplete change". The meeting ear (Snotra) landed
in code and in its own asset, but Galdr's *maps* — the router, the naming table,
the component inventory, the registry, the install asset — did not know the ear
existed. A sibling capability, **Þing** (the assembly hall, plan 53), arrived the
same day and was referenced by `SKILL.md` but registered nowhere else.

### What landed
- **`SKILL.md`** — `assets/snotra-meeting-ear.md` added to the router
  (`assets[]` 24 → 26; the Þing row arrived with the asset).
- **`assets/norse-naming.md`** — **Snotra** (the ear) and **Þing** (the assembly
  hall) rows in the platform component map.
- **`assets/runtime-components.md`** — `bin/snotra-capture.sh`,
  `bin/snotra-transcribe.sh`, `bin/snotra-ensure.sh` in the `bin/` inventory.
- **`assets/registry.md`** — a **Fleet services** section: the eight services
  `bin/fleet-ensure.sh` materializes (`well-mcp` · `ratatoskr` · `mill-worker` ·
  `embed` · `cards` · `skills-mcp` · `skuld` · `snotra` on :8321).
- **`assets/installation.md`** — the `snotra` step row and the `fleet` row now
  names the ear's MCP face and the `~/.fleet` command materialization.
- **`assets/README.md`** — the asset index (27 → 28 rows).
- **`.agents/agents/galdr.md`** — re-synced with the canonical skill (the
  `surfaces` gate: the agent surface had drifted behind `SKILL.md`).

### Files
- `.agents/skills/galdr-ymirsystem/SKILL.md`
- `.agents/agents/galdr.md`
- `.agents/skills/galdr-ymirsystem/assets/{norse-naming,runtime-components,registry,installation,README}.md`
- `.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md`
- `.agents/skills/galdr-ymirsystem/assets/thing-assembly-hall.md`

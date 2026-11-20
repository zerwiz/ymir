---
name: smidja
description: >-
  Smíðja — the smithy, the agent factory. Load when working on the smithy itself:
  the agent roster and phases, phase envelopes, the trace/sessions store, or the
  Visualizer UI (:8437). Load before changing agent factory behaviour, install,
  or the visualizer.
allowed-tools: read,write,bash,glob,grep
---

# smidja-factory — the smithy — agent factory: roster, phases, envelopes, visualizer

The smithy forges and runs workers. Völundr is its master craftsman.

- **Full reference:** `AGENTS.md` (in this folder) — the canonical smithy doc.
- **Scripts:** `scripts/` · **Visualizer UI:** `apps/visualizer` (:8437).
- **Install/ports/observer:** `.agents/skills/galdr-ymirsystem/assets/smidja.md`.
- **Runtime:** `bin/smidja-bootstrap.sh`, the Session/Trace/Decisions/Stats gates.

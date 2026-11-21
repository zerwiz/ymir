# bridge · 2.1.2 · 2026-11-21 — the last pages that taught the retired engines

The review of the chain (`2026-11-21-one-door-carries-the-fallback.md`) found more pages that still taught
the retired desktop model server and the model daemon as local roads. Only llama.cpp is a local road.

## Removed

- `.env.example` — `CMD_LOCAL_URLS` no longer lists `:1234` and `:11434` as local model servers.
- `README.md` — the pi provider line and the install table name the llama.cpp rail and Bifrost only.
- `.agents/agents/galdr.md`, `.agents/skills/galdr-ymirsystem/SKILL.md`, `…/assets/README.md` — the index row
  for `local-models.md` says what that page now teaches.
- `.agents/skills/galdr-ymirsystem/assets/smidja.md`, `…/hlidskjalf-ui.md`, `…/installation.md` — no `:1234`
  engine, no `pi-lmstudio` package row.
- `apps/hlidskjalf/server/index.ts` and `bin/engine/ymir-install.sh` — comments only; no behaviour changed.

## Kept, on purpose

| Where | Why it stays |
|---|---|
| `docs/features/bilskirnir-choose-a-model.md` lines 35, 75 | describes that app's own scan default, whose code is in its own repository; it changes there first |
| `apps/hlidskjalf/server/hlidskjalf-usage.sh`, `bin/desktop/hlidskjalf-usage.sh`, `index.ts` `LOCAL_MODEL_PREFIXES`, `Stats.tsx` | they classify **old usage records** that carry those names; a detector, not a road |
| `.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` | a detector regex that finds a forbidden provider string |
| `bin/records/mimir-reflect.sh`, `.agents/skills/bragi-translation/assets/programs.md` | each says *never* point at the daemon — a prohibition, not a teaching |
| `AGENTS.md`, `TODO.md`, `bin/model/catalog.sh`, `bin/pi/pi-ensure.sh`, `bin/bridge/*`, `bin/gates/checks.d/0400-*`, the docs' CHANGE LOGs | dated records of the retirement (RULES/06: a record is not rewritten) |
| `assets/reference/docs/apodex/Final Report.md` | a third party's own report, kept verbatim as reference |
| `.agents/skills/galdr-ymirsystem/assets/local-models.md` line 21 | names the two engines once, so galdr recognises one found on a seat and reports it for removal |

# One name everywhere: the map, the lore and the contract agree (plan 374)

At the Allfather's choices D1–D10, the component map, the lore and the contract's lore table were aligned with each
other, with the homepage and with the code.

## What changed

| File | Change |
|---|---|
| `.agents/assets/agents/naming.md` | seven doubled rows made one; 38 figures added; Élivágar named; Brokk's row is the counsellor's role (RULES/44); Heimdall is the key ward; Hermóðr is the gateway; Snotra is the meeting ear; Skuld keeps what shall be; Hvergelmir is the news app; the planned and built states match the code; the broken Hófvarpnir row (a missing quote) fixed; an owner table for every MCP tool, unit and container |
| `docs/lore.md` | chapter XXXVIII appended; nothing above it rewritten |
| `AGENTS.md` | a dated section appended that corrects the lore table (one Völundr, Þjazi retired, Heimdall, the moved paths, the eight) |
| `docs/lore-claims.tsv` | Gungnir, Gunnlöð and Kádlín marked planned; corrected probes for Kvasir (the route lives in `.agents/roles.yaml`), Himinbjörg, Vörðr, Heimdall and Hermóðr; new rows for Bölþorn, Dellingr, Týr, Snotra, Skuld, Élivágar and Mánagandr's door |
| `docs/features/apps-install-and-update.md` | the system is named Élivágar |
| `docs/lorestory.md` | a change-log line naming the five sentences owed at the next recording |

## Proof

- `bin/records/lore-audit.sh run` before: **24 true · 13 partial · 4 false · 3 planned**. After: **36 true · 11 partial · 0 false · 4 planned**, over 51 claims (seven new rows). Nothing reads false: Gungnir, Gunnlöð and Kádlín are planned, and Hermóðr is the gateway that runs.
- `bin/agents/name-registry.sh collisions` (against a scratch copy of a home): one collision before, the same one
  after (`heimdall`, a host and a subsystem); the 38 new rows add none.

## CHANGE LOG

- 2026-11-25 — review-mend: added missing heading for #944

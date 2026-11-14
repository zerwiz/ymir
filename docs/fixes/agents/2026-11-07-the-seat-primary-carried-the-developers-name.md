# The seat primary carried the developer's name — and the developer's role file

**Date:** 2026-11-07 · **Component:** agents

## What was wrong

The Allfather: *"sindri are the developer. youre the nidas 'brokk' agent. your name are conflicting with the developer."*

He was right twice over. `hodd/identity/seats.yaml` read `nidavellir: primary: sindri, role: smith, role_file:
.agents/agents/sindri-developer.md` — and that file is a **subagent**, `mode: subagent`, the developer Eindri. So this
seat's primary wore the developer's name *and* pointed at the developer's role file, while the counsellor's own file
(`.agents/agents/brokk.md`, `mode: primary`, `descriptor: the counsellor`) sat unused. The renderer then composed the role
path from the primary name — `.agents/agents/Hávi.md` — which did not exist, so the render named a file nothing followed.

## What was done

- **the seat is renamed and re-pointed** (in the home, `8384550d`): `nidavellir` primary **Hávi**, role `counsellor`,
  `role_file: .agents/agents/brokk.md`. Sindri stays exactly where he belongs, the Eindri who forges.
- **`.agents/agents/Hávi.md`** — this commit — a link to `brokk.md`, so the render resolves on **every** machine that runs
  `bin/seat/seat-surface.sh`, not only on the one where the link was made by hand. One source, no second copy.
- **re-rendered**: `bin/seat/seat-surface.sh --check` now reports *every surface reads Hávi on nidavellir*.

## How it was verified

```
bash bin/seat/seat-surface.sh --check   → every harness reads Hávi on nidavellir
readlink -f .agents/agents/Hávi.md      → .agents/agents/brokk.md
bin/gates/guards.sh                     → no failing ward of this range (a mojibake finding in
                                           .agents/assets/agents/capabilities.md is pre-existing on main and belongs to the
                                           hand that owns that file)
```

## CHANGE LOG

- **2026-11-07** — Written with the link, at the Allfather's word.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

# snotra · 2026-11-11 — the house letter design: thirteen letter types, themed, and findable

## Files
- `systems/snotra/services/letters/letter-design.py` (new) — blocks, themes, types, gallery, self-test
- `systems/snotra/services/letters/templates/house/types/*.md` (new, 13) — generic letter types, placeholders only
- `systems/snotra/services/letters/mail-send.sh` — a body that opens with `theme:` is designed by `letter-design.py`
- `.agents/skills/snotra-letters/SKILL.md` (new) — names all four template shelves and how to use them
- `.agents/assets/agents/subsystem-docs.md` — the letters row, so `where.sh` answers for this folder
- `docs/features/letter-templates.md`, `docs/features/_catalogue/entries/02-108-the-house-letter-design.md`

## Why
The operator, 2026-11-11: *"we need more templates. some need to have the design from Ymir's colours"* and *"why isn't
the system knowing of all our templates and how to use them"*. Measured: four template shelves existed (seven vendored
layouts, the meeting letter, ten occasion texts in `midgard/email-templates/`, three house drafts), the renderer knew
one of them, none used Ymir's colours, and no skill described any of them — `skill-find "email template"` returned
nothing.

## What changed
Letters written as plain words with markers are rendered into email-safe HTML. Themes: `ymir` reads its colours from
`midgard/design-system/tokens.css` (the tokens Hlidskjalf uses), `ymir-light`, `plain`, and any theme the operator
keeps in the home (`hodd/identity/letters/themes.yaml`) — company names and colours never enter this public repository.

## Proof
`python3 systems/snotra/services/letters/letter-design.py --self-test` → `ok (13 types × 7 themes)` with the operator's
home themes, `ok (13 types × 3 themes)` without a home. A `mail-send.sh draft --dry-run` of a typed letter produced
`multipart/alternative` with the designed HTML and a plain part without the header.

## CHANGE LOG

- **2026-11-11** — written with the change (nidavellir, plan 250).

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

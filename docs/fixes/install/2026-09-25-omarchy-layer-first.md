## install · unversioned · 2026-09-25 — the Omarchy layer can be raised first

## Why
A user who does not have Omarchy yet had no way to ask Ymir to stand the
first-class desktop layer up **before** the portable core: `step_omarchy` always
ran last. The Allfather asked for an option and for the how-to to live on the
homepage and in the planning doc.

## What
- `bin/ymir-install.sh` gains `--omarchy-first` (alias `--omarchy`): the Omarchy
  layer runs as the first step, then the core; without the flag it still runs
  last. It does **not** install the Omarchy OS (that is upstream) — it runs
  `bin/omarchy-install.sh` first, then the core.
- `step_omarchy` detects its host, so both orderings report a clean `SKIP` on a
  non-Omarchy machine (Rule 05) — never a faked layer.
- Documented for the reader: `README.md` (homepage — "No Omarchy yet? Raise the
  layer first"), `.agents/skills/galdr-ymirsystem/assets/installation.md` (usage
  line, a subsection, and the steps note), and
  `.agents/skills/ymir-host/assets/omarchy.md` (the owning asset).

## Proof
- `bin/ymir-install.sh --check --omarchy-first` → step `[1/25] omarchy layer
  (first)`, then `panes`; the `omarchy` and `local-model` rows report honestly.
- `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` → 15/15 PASS.

### Files
- `bin/ymir-install.sh` — the flag, the parse, the two orderings.
- `README.md` — the homepage subsection.
- `.agents/skills/galdr-ymirsystem/assets/installation.md` — usage + subsection +
  steps note.
- `.agents/skills/ymir-host/assets/omarchy.md` — the layer-first note.
- `docs/fixes/install/2026-09-25-install-stands-the-local-model-up.md` — extended.

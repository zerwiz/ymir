## hlidskjalf · unversioned · 2026-11-14 — the doors and the harness readers resolve the home

### Why

`defaults-guard` refused the first push of this branch: `bin/desktop/hlidskjalf-agents.sh`
restated the home twice (`STATE_DIR="${STATE_DIR:-$HOME/Documents/ymirhome/state}"`) and
`bin/desktop/hlidskjalf-usage.sh` guessed `~/Documents/ymirhome/bilskirnir/...` for Bilskirnir's
engine homes. A restated path is drift by definition (RULES/07): a home that moves keeps working on
the machine that wrote the default and breaks everywhere else.

### What changed

- **`hlidskjalf-agents.sh`** falls back to the one resolver (`hoard_state_dir`,
  `hoard_settings_dir`, then `ymir_home_root`) and leaves the paths **empty** when no resolver is
  readable — a card with no records is honest; a card reading a guessed path is not.
- **`hlidskjalf-usage.sh`** resolves the home through `ymir_home_root` before the Python reader
  runs, and passes it in; the Bilskirnir engine glob is built from that answer.
  **Measured after the change:** Hermes' homes are `.hermes · nanna · bot_2eayQCr5VCab ·
  bot_aCiyAD2OpVrM`, 17 sessions — identical to the hardcoded path it replaced, so the fix costs
  nothing and the guess is gone.

### Files

`bin/desktop/hlidskjalf-agents.sh` · `bin/desktop/hlidskjalf-usage.sh` ·
`docs/features/inspect-any-app-and-agent.md` (its CHANGE LOG, which `rules-compliance-guard`
requires of a new page).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #759

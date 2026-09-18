## hlidskjalf · unversioned · 2026-09-16 — the delivery gates install themselves; rename drift mended

### Why
- **Install seam.** `bin/ymir-install.sh` gains step **`gates`** (after
  `loaders`): `bin/secret-guard.sh --install` seats the pre-commit guard and
  `bin/changelog-guard.sh --install` the pre-push (branch + changelog). A fresh
  clone now gets the delivery gate without a manual step — `--check` reports it
  as `gates OK|WARN`, the consent preamble names it, and
  `assets/installation.md` carries the row in the same change.
- **Drift mended — found by the compliance gate, not by me.** Two symlinks
  still pointed at the retired `galdr-cli` skill, so the last rename was not in
  fact complete: `.agents/agents/galdr.md` (Galdr's agent surface was a **dead
  link**) and `.agents/skills/tyr-check/assets`. Both repointed at
  `galdr-ymirsystem`, which is where the skill and its assets live.
- **`AGENTS.md` TOON mend.** The `security[4]` block carried a rule wrapped
  across two lines, which the checker counted as a fifth row. Joined to one
  line; the block now declares and holds exactly four.
- **Compliance.** All ten Galdr gates green: toon · naming · mocks · syntax ·
  json · sync · surfaces · assets · duplicates · governed.

### Files
- *(carried from the frozen CHANGELOG.md)*

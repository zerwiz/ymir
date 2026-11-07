# forge · 2026-11-07 — the unpushed branches consolidated into one integration

### Why

Nineteen local branches carried work that never reached a PR: some real (utgard boxes
and lanes, the harness extensions, portability routing, the fix notes of early
November), some already superseded on main. The Allfather asked that they be melded
into one branch and one pull request rather than left to rot on the machine.

### What

`integrate/unpushed-2026-11-07`, branched from `origin/main` and merged in this order:

- `integrate/local-consolidation` (71 commits — already contained `fix/snotra-watch-coalesce`,
  `feat/every-harness-extensions`, `fix/portability-routing`, `feat/snotra-plan144-full-build`,
  `fix/garmr-retention`)
- `eindri/jev-preset-bench`
- `integrate/night-2026-11-06`
- `integrate/session-2026-11-06`
- `feat/one-door-for-the-registers`
- `rules/platforms-and-tiers` (main's shim and ratchet are newer; the branch's fix note travels)
- `pr524-rebase` (well recall already on main, newer: main kept)
- `yggdrasil/utgard-box` (boxes, lanes, the factory in a box; `backup-p2p4` is contained in it)

The woven registers (`bin/README.md`, the folder indexes, `.agents/backend/README.md`,
`.agents/assets/agents/capabilities.md` and its fragments, `FEATURES.md`) were
regenerated from the merged tree rather than merged by hand.

### Not merged, and why — nothing deleted

- `compliance-fix` (2026-10-04) — 76 substantive conflicts; merging it would revert a
  month of main.
- `yggdrasil/gimle-suite` (2026-10-22) — 27 substantive conflicts.
- `feat/library-of-records` (2026-10-23) — its registers and guards were superseded by
  the regenerative register tree (plans 174 and 211).
- `archive/main-old-history`, `gate/registry-realm-key`, `eindri/engine-fleet`,
  `eindri/fleet-ops-residue`, `eindri/heart-migration`, `fix/pretest-headless-boot`,
  `fix/ci-verify-loud-failures`, `fix/sessrumnir-detach-update`, `yggdrasil/sindri`,
  `sessrumnir/seat-hall-graphics`, `eindri/demo-task` — these carry the whole old
  history (880–1160 commits each) and are snapshots, never merges.
- `rescue/local-main-2026-11-06`, `backup/the-gate-parses-2026-10-23` — safety copies.

### Verified

- `bin/gates/guards.sh` → PASS (28 wards).
- `bin/gates/checks/portability-ratchet.sh check` → ok on every verb.
- Registers regenerated from the merged tree: `inventory.sh`, `capabilities.sh`,
  `weave-features.sh` all clean.

### Files

- the merge commits themselves, plus the regenerated registers.

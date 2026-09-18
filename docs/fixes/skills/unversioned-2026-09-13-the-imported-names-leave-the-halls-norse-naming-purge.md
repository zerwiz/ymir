## skills · unversioned · 2026-09-13 — the imported names leave the halls (Norse naming purge)

### Why
- **"firstmate" retargeted to Ymir's own names across every Ymir-owned surface.**
  The upstream distro's nautical vocabulary is gone from the docs, skills, `bin/`,
  config, and the Hlidskjalf review copy: `firstmate` → **Brokk**, `secondmate` →
  **Eindri-home**, `crew`/`crewmate` → **Eindri**, `captain` → **Allfather**
  (`docs/lore.md`, `docs/Architecture.md`, `.agents/agents/brokk.md`,
  `.agents/skills/herdr-panes/assets/{herdr,tmux}-backend.md`,
  `.agents/skills/eindri-homes/assets/control-plane.md`,
  `.agents/skills/saga-bearings/assets/board-template.html`,
  `.agents/skills/ymir-host/assets/thjazi.md`, `bin/README.md`,
  `apps/hlidskjalf/**`).
- **Engine literals kept.** Every real upstream identifier stays verbatim — the
  Herdr labels (`firstmate`, `2ndmate-<id>`, `firstmate-<id>`), the home marker
  `.fm-secondmate-home`, the envelope `FIRSTMATE_OP: ` and `[fm-from-firstmate]`,
  and all `FM_*`/`fm-*` names — because `.agents/backend/` (the vendored engine)
  and `assets/reference/` (provenance) are untouched.
- **Licensing.** `NOTICE` now records the upstream **firstmate** distro
  (`github.com/kunchenguid/firstmate`, MIT, © kunchenguid) and a README "Built on"
  section points to it; the MIT copyright/permission notice is retained.
- **Governed asset:** `galdr-ymirsystem/assets/hlidskjalf-ui.md` records the Allfather
  review copy in the same change. `complianc

### Files
- *(carried from the frozen CHANGELOG.md)*

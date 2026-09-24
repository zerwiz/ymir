## runtime · 2026-09-24 — the Snotra asset names the boot contract it actually has

### Why
`tools/mill/systemd/snotra.service` was changed to `WantedBy=ymir.target` while resolving
the PR #179 merge, so the ear joins the ONE target the install enables once and boot pulls
the whole role set. The owning Galdr asset still said `WantedBy=default.target` — the
pre-autoboot contract. Code and asset disagreed, and a future hand reading the asset would
have believed the wrong one.

The same merge also taught the asset's sibling document the other correction it needed:
Meetily-Local has **no calendar and no call detection** (you click record), so "follows you
into meetings" is built around the engine, never assumed from it.

### What
- `.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md` — the unit's install
  contract corrected to `ymir.target`, with the reason stated in place.

### Verified
- The line now matches `grep -i wantedby tools/mill/systemd/snotra.service` exactly.

### Files
- `.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md`

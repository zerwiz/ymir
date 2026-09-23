## runtime · unversioned · 2026-09-23 — the desktop entries survive an install (Smiðja back in the menu)

### Why
- **Problem (Allfather, 2026-09-23):** *"the npm installation did not update the
  4 apps in omarchy's menu and one is missing — smidja."* Two causes:
  1. **A stray line deleted Smiðja's entry.** At the end of `design-icon.sh
     install`, `[ -f "$apps_dir/ymir-smidja.desktop" ] && rm -f …` removed the
     launcher entry the loop had *just written* — a leftover from the
     `ymir-visualizer → ymir-smidja` rename. The correct sweep already exists
     below it (`for stale in … ymir-visualizer`). Removed.
  2. **An install never refreshed the entries.** The launcher entries outlive the
     tree that wrote them; `npm install` updated the package but left the menu
     untouched, so a stale or missing entry stayed invisible until an operator
     looked. `bin/fleet-deploy.sh` (the postinstall deployer) now also runs
     `bin/design-icon.sh install` and `bin/desktop-place.sh apply` — best-effort
     and host-gated, opt out with `YMIR_SKIP_DESKTOP=1`.
- **Result:** four entries stand — Hlidskjalf · Óðrerir · Sessrúmnir · Smíðja —
  and an install keeps them current.

### Verified
- `bin/design-icon.sh install` now reports **all four** and
  `~/.local/share/applications/` holds `ymir-hlidskjalf · ymir-odrerir ·
  ymir-sessrumnir · ymir-smidja .desktop` (Smiðja present again).
- `bin/fleet-deploy.sh --dry-run` reports the desktop refresh step.
- `bash -n` clean.

### Files
- `bin/design-icon.sh`
- `bin/fleet-deploy.sh`

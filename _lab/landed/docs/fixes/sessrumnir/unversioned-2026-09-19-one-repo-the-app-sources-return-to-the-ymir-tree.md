## sessrumnir · unversioned · 2026-09-19 — one repo: the app sources return to the Ymir tree

### Why
- `f7f3063` split the apps out ("step_apps pulls each app repo; the monorepo stops tracking them").
  Every fault of 2026-09-18 lived at the seam that split created: vite.config.ts, electron/,
  midgard/, install.sh and the seat's own postinstall each belonged to an app whose source this
  repo did not hold.
- The sources return: `git checkout 6fb7124 -- apps/` restores hlidskjalf, odrerir, sessrumnir,
  smidja and smidja-factory into `apps/` — 751 files. Plan 35, first step.
- Still to come in this plan: retire the four npm deps and `step_apps`, build from `apps/`, one
  publish, and the empty-HOME proof.

### Files
- `(see the body)`

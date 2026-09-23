## hlidskjalf · unversioned · 2026-09-23 — the hearth warms from the floor, not a third up

### Why
- **Problem (Allfather, 2026-09-23):** *"the ember … are not rendering from the
  bottom but from one third up"* in Sessrúmnir.
- **Root cause:** the **haze** — the soft warm pools that read as the fire's glow —
  was seeded in a band a fraction down from the top:
  `y: H * 0.3 + Math.random() * H * 0.7`. On the landing's short hero (~one
  screen) `0.3H` read as "the whole hero"; in a **tall chat column** it puts the
  glow's upper edge a third down, so the hearth appears to start a third up while
  the ember dots rise from the floor. The embers themselves were already correct
  (`y: H + …`, from/below the bottom).
- **Fix:** anchor the haze to the **floor**: `y: H - Math.random() *
  Math.min(H * 0.28, 240)` — the pools sit in the bottom band (capped at 240 px so
  a tall window is not one wash), and the fire rises from the bottom edge as the
  landing's does. Applied to **every** copy, so the fire stays one:
  - `apps/sessrumnir/src/renderer/src/components/ember-background.tsx` (the chat port)
  - `apps/sessrumnir/src/renderer/src/components/EmberBackground.tsx`
  - `apps/sessrumnir/src/renderer/src/assets/ember.js`
  - `midgard/design-system/ember.js` (the canonical shared original)
  - `apps/hlidskjalf/midgard/design-system/ember.js`, `apps/odrerir/src/scripts/ember.js`,
    `apps/smidja-factory/apps/visualizer/src/lib/ember.js`

### Verified
- All seven files carry the floor-anchored seed; no `H * 0.3 + … * H * 0.7`
  remains anywhere under `apps/` or `midgard/`.
- Sessrúmnir typecheck shows **only pre-existing** errors (main, bridge-http,
  file-tree); nothing in the ember files.

### Files
- the seven ember copies above

# runtime · 2026-09-23 — the fleet graph's labels readable

## Why
The fleet graph's node-labels were nowrap without a width clamp: the long
card-names spilled across their neighbours and the dense rows stacked the
text — the names became a smear.

## What
- `.node-label` clamps at 96px with ellipsis + a backing tile (z-order above
  the beams); the full name rides the hover title.

## Files
- `apps/hlidskjalf/src/gates/Fleet.tsx` · `apps/hlidskjalf/src/styles/components.css`

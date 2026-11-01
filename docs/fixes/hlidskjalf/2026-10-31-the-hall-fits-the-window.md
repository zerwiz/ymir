# The hall fits the window — three `1fr` columns and a search box pinned the width

**Date:** 2026-10-31 · **Component:** hlidskjalf · **Status:** fixed, measured at five widths

## What was wrong

The Allfather: *"hildskjafs ui arw overflowing to the rigt. it dot adapt to screen size."* Measured with a
headless browser at a 1280 window, logged in: `document.documentElement.scrollWidth` was **1682** against a
`clientWidth` of **1280** — the hall was 402 px wider than the screen and the browser scrolled sideways.

Three faults, all the same class of mistake:

1. **`.shell { grid-template-columns: var(--rail-w) 1fr }`.** `1fr` is `minmax(auto, 1fr)`: its AUTO minimum
   lets a wide child (a long line of text, a table, a monospace row) push the column past the viewport. The
   column became **1485 px** inside a 1280 window.
2. **`.files-layout { grid-template-columns: 300px 1fr }`** — the same mistake on the Files gate, where a
   **2527 px** line of `.jsonl` widened the pane and the document with it.
3. **`.search { flex: 1; max-width: 440px }`** with a 280 px min-content: the topbar could not shrink, so the
   last menu sat **47 px** past the right edge (`.menu-wrap` at `left: 1327` in a topbar ending at 1280).

## The fix

- `grid-template-columns: … minmax(0, 1fr)` in both grids, and `min-width: 0` on the shell's own children
  (`.rail`, `.topbar`, `.stage`, `.stream`) — the shrink floor a grid child needs.
- `.search { flex: 1 1 160px; min-width: 0 }` so a search box yields before the hall scrolls.
- new `@media (max-width: 1400px)` step: the optional topbar chips (workspace label, trace label) drop their
  text before the menus do; `.topbar { overflow: hidden }` as the last resort — a chip may be clipped, the
  document may not.
- `pre, code[class*='language-'] { max-width: 100%; overflow-x: auto; display: block }` — file content scrolls
  inside its pane.
- `.stage { overflow-x: auto }` for wide rows and tables.

## Measured after (logged in, all gates)

| window | result |
|---|---|
| 1600 × 900 | clean |
| 1280 × 800 | clean |
| 1024 × 768 | clean |
| 820 × 1180 | clean |
| 390 × 900 (mobile layout) | clean |

Measured by driving the built SPA in headless Chromium, comparing `scrollWidth` to `clientWidth` on every
gate and listing any element whose right edge crossed the viewport. Before: **1682 vs 1280**, 151 offending
elements on Fleet alone; after: none at any of the five widths.

## How to see it

The gate and the SPA serve `apps/hlidskjalf/dist`, so the fix is live after a reload (`npx vite build` was run);
the Electron window picks it up on refresh.

# smidja · 2026-11-14 — the session cards fit a narrow window

**Component:** smidja · **Branch:** `eindri/smidja-header-chat` (plan 275; helm's word, 2026-11-14)
**Files:** `apps/smidja-factory/apps/visualizer/src/components/SessionsList.vue` (+ tracked `dist/`)

## Why

The sessions list is a grid whose columns were `minmax(460px, 1fr)`. A 460-pixel **minimum** cannot
shrink, so below roughly 508 pixels of window the grid pushed the page sideways: measured
`scrollWidth 484` against `clientWidth 471` at an emulated 480 on 2026-11-14.

## What changed

```css
grid-template-columns: repeat(auto-fill, minmax(min(100%, 460px), 1fr));
```

`min(100%, 460px)` keeps the 460-pixel preference on a wide screen and lets a single column shrink
to the container when the window is narrow. One line, no behaviour change above the threshold.

## Proof

Same window, CDP `Emulation.setDeviceMetricsOverride`, the sessions page, eight widths:

```
 1600 cards 3 cardW 505.3 widest 1576 scrollW 1600  ok
  891 cards 3 cardW 843.1 widest  867 scrollW  891  ok
  690 cards 3 cardW 642.2 widest  666 scrollW  690  ok
  550 cards 3 cardW 502.4 widest  526 scrollW  550  ok
  490 cards 3 cardW 442.3 widest  466 scrollW  490  ok
  471 cards 3 cardW 422.6 widest  447 scrollW  471  ok
  411 cards 3 cardW 362.6 widest  387 scrollW  411  ok
  351 cards 3 cardW 302.5 widest  327 scrollW  351  ok

overflows: 0
```

Before the change the same measurement reported an overflow at 480 (`scrollWidth 484`); after it,
`scrollWidth === clientWidth` at every width down to 360.

## Not done, named

`src/components/DecisionsView.vue:100` carries the same shape — `minmax(360px, 1fr)` — so the
decisions page can overflow a window under about 410 pixels. It is the same one-line fix; it was
not named in this errand and is recorded here so it is not lost.

## CHANGE LOG

- 2026-11-14 — the sessions grid's minimum column is `min(100%, 460px)`; measured 360 → 1600 with
  no horizontal overflow; the decisions grid's identical shape named as owed.

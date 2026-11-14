# smidja · 2026-11-14 — the smithy's header fits every width and loses no door

**Component:** smidja · **Branch:** `eindri/smidja-header-chat` (plan 275, item 13)
**Files:** `apps/smidja-factory/apps/visualizer/src/App.vue`, `src/style.css` (+ the tracked `dist/`)

## Why

The Allfather, plan 275 §02:50: *"smidjas header are not following window size"* — the crumbs
and the buttons overlapped between the breakpoints. The trail was one flat row of links and the
tools were separate flex items, so anywhere the two together were wider than the window they
simply painted over each other. Only a single `max-width: 900px` query changed anything.

He added the rule that governs the shape of the fix, 2026-11-14: *"we cannot lose the buttons
just because we're narrowing it."* So the header may tighten, shorten and wrap — it may never
drop a door to make itself fit.

## What changed

Each crumb is now one wrapper (its separator plus its own door), and the tools (live · theme ·
window) sit in their own group that never shrinks. The trail is the only part that gives ground,
in this order:

1. the word *live* goes and the dot carries the meaning (≤1240px);
2. the gaps and type tighten (≤1180px, ≤1040px);
3. the run id and the phase name shorten with an ellipsis, their full value in the tooltip
   (`flex: 1 1 0`, floor of `4ch`) — they are context, not doors;
4. the house name steps aside and the orphan chevron goes with it (≤900px);
5. only when none of that is enough does the trail take a second line (≤700px).

The measured ladder, in a real Electron window through DevTools at 19 widths from 1600 down to
360: **all six doors visible at every width, no two crumbs overlapping, the tools never crossed
or pushed out of view**. From 1600 to 740 the bar stays one line; below that it wraps.

## Proof

A private Electron window (`--user-data-dir=/tmp/ymir-smidja-header`,
`--remote-debugging-port=9444`) over this worktree's own built `dist/`, both on `#/` and on
`#/8f110045/plan-and-phase-3` (a real run id with a phase crumb), measured through CDP
`Emulation.setDeviceMetricsOverride` at 1600, 1440, 1280, 1181, 1101, 1041, 1000, 960, 901, 861,
800, 740, 700, 661, 601, 541, 480, 420, 360.

```
doors per width: 6 (every row)      collisions: 0      tools crossed: 0
bar height: 64 → 58 (≤900) → one line until 740 → 92/115 wrapped below
static: vue-tsc --noEmit 0 · vite build 0
```

## Not done, named

The session cards below the header still overflow a very narrow window (`.card` at 460px wide,
visible under 500px). That is the sessions list, not the header, and it is not this errand's
item — recorded here so it is not lost.

## CHANGE LOG

- 2026-11-14 — header re-shaped (crumb wrappers, tools group, five collapse stages); every door
  kept at every width; dist rebuilt.

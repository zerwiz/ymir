# Baseline — the chat measured at four widths (S0 of plan 222)

**Measured 2026-11-08, before any change**, on branch `eindri/sessrumnir-narrow`, by
`node scripts/probe-chat-widths.mjs`. This file is the "before" the rest of plan 222 is
judged against: it is a measurement, not an opinion, and it is reproducible — the command
below prints the same table on any machine with Chromium.

```
node scripts/probe-chat-widths.mjs --pane 400
node scripts/probe-chat-widths.mjs --pane 400 --panel files
```

## How the measurement is taken

The probe is three pieces, none of which re-draw the app:

- `scripts/probe-chat-surface.tsx` mounts the **shipping `ChatPanel`** in a real browser,
  with the real store, seeded from `scripts/probe/fixtures.ts` — prose that must wrap, a
  token that cannot wrap, a table, and a code block wider than any pane.
- `scripts/probe/measure.js` asks two questions of every element: does its right edge
  cross the nearest box that **hides** it (a pane that refused to shrink), and is its
  content wider than its own box while it does not scroll (text that is cut, not
  scrolled). Only the outermost offender of a subtree is listed.
- `scripts/probe-chat-widths.mjs` compiles the shipping stylesheet with the same Tailwind
  compiler the vite plugin uses, bundles the page with esbuild, and drives headless
  Chromium once per case.

A `pre` and a `.overflow-x-auto` are allowed to be wider than their box: a code block
scrolls inside itself on purpose. A pane's vertical scroller is **not** allowed to be a
horizontal one — `overflow-y: auto` computes `overflow-x` to `auto` as well, so the message
list silently becomes a sideways scroller the moment a long line arrives.

## The table

`chat` is the width the chat column actually got; `column` is the width of the message
column inside it. A `column` wider than its `chat` is the fault he reported.

| case | window/pane | chat | column | crosses | is-wider | page overflow | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| window 1280 | 1280 | 1280 | 952 | 0 | 0 | 0 | clean |
| window 1024 | 1024 | 1024 | 952 | 0 | 0 | 0 | clean |
| window 960 | 960 | 960 | 952 | 1 | 0 | 0 | OFFENDERS |
| window 800 | 800 | 800 | 952 | 1 | 0 | 0 | OFFENDERS |
| pane 400 in 1400 | 400 | 400 | 952 | 1 | 0 | 0 | OFFENDERS |
| window 1280 panel=files | 1280 | 1000 | 952 | 2 | 0 | 0 | OFFENDERS |
| window 1024 panel=files | 1024 | 744 | 952 | 2 | 0 | 0 | OFFENDERS |
| window 960 panel=files | 960 | 680 | 952 | 2 | 0 | 0 | OFFENDERS |
| window 800 panel=files | 800 | 520 | 952 | 2 | 0 | 0 | OFFENDERS |
| pane 400 in 1400 panel=files | 400 | 120 | 952 | 8 | 2 | 0 | OFFENDERS |

## What the offenders are

### The message column does not shrink — at every width below 1024

`div.mx-auto.max-w-5xl.px-4` — the message column — is **1024 px wide no matter how narrow
its pane is**: 64 px too wide at 960, 224 px too wide at 800, 624 px too wide in a 400 px
pane, and 904 px too wide when the side panel leaves the chat only 120 px.

```
crosses  window 800                     over 224 px  (1024 px element in a 800 px box)
crosses  window 960                     over  64 px  (1024 px element in a 960 px box)
crosses  pane 400 in 1400                over 624 px  (1024 px element in a 400 px box)
crosses  window 800 panel=files          over 504 px  (1024 px element in a 520 px box)
crosses  pane 400 panel=files            over 904 px  (1024 px element in a 120 px box)
```

It is a flex item of the message scroller and carries `min-width: auto`, so its floor is
its content's minimum width — the code block's 952 px of unbroken `whitespace-pre` — and
`max-w-5xl` (1024 px) becomes the width it takes, not the ceiling it should be. The parent
clips it, so there is no page scrollbar to warn anybody: the right of every line is simply
gone. **This is the sentence he cannot read.**

### The file pane overruns the panel by 9 px at every width

`div.flex.min-w-0.shrink-0` inside the side panel is 280 px in a 271 px box, in every case
where the file tree is open — a fixed `DEFAULT_FILE_PANE_WIDTH` against a panel narrower
than the sum of its parts.

### The side panel steals the chat down to 120 px

In a 400 px pane with the file tree open, the panel takes 280 px and the chat is left 120.
`resolveSidePanelMetrics` is given the column width but caps the panel at the **whole**
column, with no reservation for the chat beside it.

### The composer overflows a 400 px pane

At 120 px of chat the composer's button row (`div.font-chat.flex.items-center`) crosses its
box by up to 251 px, the composer is 104 px tall instead of 76, and the toolbar row
overflows by 34 px. Nothing is wrapped, nothing is hidden: the buttons are simply painted
outside the pane.

## What this baseline does NOT say

- It says nothing about colour, spacing or taste. It measures edges.
- `pageOverflow` is 0 in every case, which is exactly why the fault went unnoticed: the
  pane's `overflow: hidden` absorbs the overflow, so the window never grows a scrollbar
  while the text disappears.

## CHANGE LOG

- **2026-11-08** — Taken before the first fix, as S0 of plan 222: four window widths, a
  400 px pane in a 1400 px window, and each of those with the file tree open.

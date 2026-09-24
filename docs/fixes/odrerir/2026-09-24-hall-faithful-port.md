# odrerir · 2026-09-24 — the hall board is the ORIGINAL again (the never-simplify law)

## Why
The Allfather's verdict, twice: "DO NEVER EVER FUCKING SIMPLIFY — the hall
page should have the SAME layout as it had." My first React port was a
SKELETON of the Astro board — tally numbers and empty slots — not the board.
The original page's full anatomy (the dealt slate stack with its option cards,
recommended marks, freeform word and the 512-byte queue guard, stack
navigation, the dispatch picker, the carved ledger thread rows, fail-closed
render) had been dropped, and a second defect surfaced: the saga payload was
injected wrapped in its own `<script>` tags, so `new Function` choked on the
closing tag and the machinery stayed silent.

## What — the original, whole
- `src/hall/lh-main.html` — the ORIGINAL `<main id="livehall">` markup,
  extracted verbatim from the Astro page (git history).
- `src/hall/lh-saga.json` + `src/hall/lh-board.js` — the original saga payload
  and the original board machinery, verbatim (the board script now parses:
  the extraction had kept the closing `</script>`; re-cut between the tags).
- `src/hall/lh-scoped.css` — the ORIGINAL kit (`cloth.css` + `livehall.css`,
  393 lines restored from git), every selector scoped to `#livehall` so the
  board keeps its exact layout without leaking into the shell.
- `LivehallBoard` renders the raw main via `?raw`, injects the saga JSON, and
  runs the original script once per mount — the same ids, the same machinery.
- A staged wrapper (`hall-stage`) so the board's own scroll is its own.

## Verified (in the window's own DOM, CDP)
- tally: "4 errands armed · 265 runes carved · 16 projects · 4 on the loom ·
  0 wake queue · 5 smiths" — the ORIGINAL wording.
- the dealt call: "an armed errand · bragi · about: … · decide: …
  smith: bragi · Queue the word · queued" — the slate card with its marks,
  the freeform queue guard, "4 slates armed · dealt by hand".
- "read live from the hall's own snapshot — nothing here is written back".
- Tickets: 13 rows, chip connected, click opens the detail — title + 89-char
  description + the stat-strip (the second complaint, proven).

## Files
- `apps/odrerir/src/hall/{lh-main.html,lh-saga.json,lh-board.js,lh-scoped.css}` (new)
- `apps/odrerir/src/components/LivehallBoard.tsx` (faithful port)
- `apps/odrerir/src/App.tsx` · `src/hall.css`
- `.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md` (appended)
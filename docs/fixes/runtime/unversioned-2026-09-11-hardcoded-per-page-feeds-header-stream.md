## runtime · unversioned · 2026-09-11 — Hardcoded per-page feeds (header + stream)

### Why
- **New:** every gate has its own hardcoded, domain-appropriate rolling feed
  (16 pools, `src/data/feeds.ts`) — Fleet, Tasks, Well, Runes, Reviews,
  Processes (Valhalla), Files, Chat, Forge, Runtime, Cron, Sessions, Trace,
  Decisions, Stats, Profile. Extra Kaia “oracle by the well” lines for the chat
  page.
- **Header:** a live `PageFeed` now sits in the page header of every gate
  (glyph + hint on the left, the current page's latest 3 messages on the
  right), rolling.
- **Stream:** the bottom Stream keeps each page's last **40** domain messages,
  with the fleet-wide feed as fallback. A generator tops it up every 2.4s and
  the page is seeded on first visit so it is never cold.
- **Verified:** `tsc` + `vite build` green, SPA 200, compliance 8/8, smoke 8/8,
  lint 4/4.

### Files
- *(carried from the frozen CHANGELOG.md)*

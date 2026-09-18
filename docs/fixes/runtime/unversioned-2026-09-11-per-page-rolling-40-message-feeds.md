## runtime · unversioned · 2026-09-11 — Per-page rolling 40 message feeds

### Why
- **Change:** the bottom stream is no longer one global 120-line feed. Every gate
  keeps its own rolling window of the **last 40** messages, and events are routed
  to the page they belong to (module → gate: `well`, `sessions`, `forge`,
  `runes`, `cron`, `reviews`, `processes`), with the fleet-wide feed as fallback.
  The stream header shows the current page. `STREAM_WINDOW = 40`, matching the
  chat's `CHAT_WINDOW = 40`.
- **Verified:** `tsc` + `vite build` green, SPA 200.

### Files
- *(carried from the frozen CHANGELOG.md)*

## hlidskjalf · unversioned · 2026-10-20 — Snotra looks like the house

### What

The first Snotra gate was a bare list. It now uses the hall's own surfaces:

- `stage-head` / `stage-title` / `stage-deck`, `MetricTile` grid (meetings, decisions,
  actions, unresolved addresses), `chips` for lane filters, `panel` + `data-table` for
  the shelf, `btn` / `btn-primary` for the actions.
- The detail panel has tabs — **record · decisions · actions · people** — each rendered
  from the record (`/api/snotra/meeting` now returns the arrays).
- Participants show an unresolved address in the warning tone; the send button is
  disabled until a draft exists; a sent state names the Gmail message id.

### Verified

- `tsc --noEmit` clean; SPA rebuilt and re-raised on `:3888`; API on `:3889`.
- The pilot opens with 6 decisions, 16 actions, 4 addressed participants.
- Two Hlidskjalf windows are on monitor 2 (the Electron seat and a Chromium app window).

### Not verified

- No browser click-through of Prepare/Send; no component tests.

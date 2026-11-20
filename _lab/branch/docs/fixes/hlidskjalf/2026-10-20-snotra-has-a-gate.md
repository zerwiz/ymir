## hlidskjalf · unversioned · 2026-10-20 — Snotra has a gate

### What

The gate gains a **Snotra** page and its API:

- `GET /api/snotra/meetings` — reads the store and the project meeting shelves; a
  broken record is skipped, a missing one is not an error.
- `GET /api/snotra/meeting?id=` — the record text plus participants and counts.
- `POST /api/snotra/draft` — calls `mail-send.sh draft --from-record`; returns the draft id.
- `POST /api/snotra/send` — validates `r-<digits>` and calls `mail-send.sh send`.
- The page lists meetings, opens one, shows participants and the record, and offers
  **Prepare draft** then **Approve & send**. Nothing edits a record.

Registered as gate `snotra` (glyph ᛊ) with title/description metadata.

### Verified

- API live on `:3889`: the pilot returns 6 decisions, 16 actions, 4 participants with
  addresses.
- SPA built and raised on `:3888`; the bundle contains the Snotra gate.
- A Chromium app window opened on monitor 2 (DP-3) shows Hlidskjalf.

### Not verified

- No browser click-through of Prepare/Send in this pass; the endpoints are exercised by
  the door tests, not the page.
- No tests for the UI component; `tsc --noEmit` is clean.

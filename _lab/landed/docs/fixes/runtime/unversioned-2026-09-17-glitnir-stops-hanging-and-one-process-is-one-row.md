## runtime · unversioned · 2026-09-17 — Glitnir stops hanging, and one process is one row

### Why
- **`/api/reviews` ran two 60-second shell checks on every poll**, so the review board
  hung for a minute and read as a dead surface. It is memoised for a minute now, the
  same discipline the usage endpoint already follows: a board a human reads does not
  need an answer fresher than its own usefulness.
- **`/api/processes` returns the same id twice** — `systemd:dbus` arrives from two
  sources, 45 entries for 44 processes. The panel dedupes by id, so a repeated process
  renders as the one process it is, and React is no longer handed a duplicate key.
  The duplicate at the source is recorded, not hidden.
- `/api/stream` answers 200; the live stream is not broken, it was the window.

### Files
- *(carried from the frozen CHANGELOG.md)*

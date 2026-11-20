## snotra · 2026-10-23 — a declared board is executable, and every shelf has a meeting

### Files
- `bin/time/snotra/snotra-board.{sh,py}` (new — check · ensure · show, idempotent board/lists/labels)
- `bin/time/snotra/snotra_paths.py` (new — one list of meeting shelves, read by the doors)
- `bin/time/snotra/snotra-pipeline.sh`, `smoke.sh` (every shelf, richest meeting first)
- `hodd/identity/places/ymir/projects/place.yaml` (new — the house's own board)
- `docs/snotra/the-places.md`, `docs/snotra/README.md`, `FEATURES.md`

### What was wrong
- **A place named a board that did not exist**, and the only way to make it was a click: the first projection
  would fail, and a hand-made board is how two boards end up with the same name (the second "Control Tower",
  2026-10-22).
- **The doors scanned one shelf.** `svartalfaheim/<realm>/meetings/` only — so a meeting about the house's own
  work (`hodd/life/meetings/work/…`) was invisible to `--recent`, to the smoke and to the layout gate.
- **The smoke's discovery was narrower still** (`ls -dt svartalfaheim/*/meetings/*`), so its checks exercised
  whichever folder was newest rather than the richest one.

### What now stands
- `snotra-board.sh show|check|ensure` — `check` reports the board, its list count, missing lists and missing
  labels; `ensure` creates only what is absent, **finds an unmapped board by name inside the organisation
  first** (so it can never duplicate one), creates private, then refreshes the map and re-reads the board.
- **The `Ymir` board exists** (id `6adb7bae165a8594de1103ac`): lists `Decisions · Doing · Open Questions ·
  Agenda`, labels `Plan · Rule · Fix · Guard · Skill · Blocking`, and a pinned **“How this board works”** card
  whose cover is the house emblem (`ymir brown.jpg` — the bronze world-tree), with `record-key:
  ymir/board:INTRO` so a re-run updates it rather than making a twin.
- `snotra_paths.py` — the shelves: every realm's meetings, `hodd/life/meetings/*`, the shared workspace,
  overridable with `SNOTRA_MEETING_SHELVES`. `snotra-pipeline.sh --recent N` and `smoke.sh` both use it.
- **Two real drifts caught by the new smoke check on its first run:** Documentation was missing its `Blocking`
  label; Control Tower was missing every grade label its profile names. Both now `ensure`d; the smoke's first
  version of the board check also counted *another* board's meeting list as this board's — fixed.

### The fault this door exists to stop, still visible
The organisation holds **two** boards named `Control Tower`. They predate this work and are left untouched:
reaping a duplicate is the Allfather's call, not a door's.

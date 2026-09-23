# runtime · 2026-09-23 — the scribe reads the smiths true

## Why
The hall board (Odrerir) showed 0 smiths while the fleet lived: the scribe
(bin/hall-snapshot.sh) read the herdr's `name` field and filtered to three
hall-pane names. The herdr names a pane in `terminal_title` and marks the
harness in `agent` — so every smith resolved empty.

## What
- The scribe now reads `terminal_title_stripped` (falling back to
  `terminal_title`, then `agent`), naming each pane by its own title — the
  fleet's three living smiths stand on the board with their states.
- Proven: the served /livehall.json carries smiths OC, the pi hall pane,
  OpenCode — tally 223 runes, 3 smiths.

## Files
- `bin/hall-snapshot.sh`

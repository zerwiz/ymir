## smidja · unversioned · 2026-09-25 — the visualizer was handed a path that does not exist

### Why
The Allfather reported the Smidja window opening to a dark blue page and a nav bar,
nothing more. The window was innocent: its own log said
`Failed to load URL: http://127.0.0.1:8437/ with error: ERR_CONNECTION_REFUSED`.
The service behind it was dying before it could serve.

- **The cause was a dead literal.** `scripts/start.sh` resolved the smithy database as
  `${YMIR_HOME:-$HOME/Documents/ymirhome}/smidja/smidja.db`. With `YMIR_HOME` unset on
  the host, that falls to `Documents/ymirhome`, **a home that does not exist on this
  machine** (the real one is `Documents/Ymir`). The visualizer was handed a path it
  could never find and exited at once. The API log named it exactly:
  `smidja.db not found at /home/craigema/Documents/ymirhome/smidja/smidja.db`.
- **A Rule 07 violation, not a typo.** The path is the operator's, so it must resolve
  through the ONE resolver and never a literal default. `scripts/start.sh` already
  sources `bin/hoard-lib.sh`; it simply did not use it here.
- **Mended** to resolve the home through `ymir_home_root` (the resolver that
  `hoard_root` itself calls) and to name the DB only when it exists. `hoard_root` was
  tried first and was WRONG: it returns the hoard (`<home>/hodd`), so the path came out
  as `<home>/hodd/smidja/smidja.db`. The resolver's own comment says "the hoard inside
  the home"; the smithy DB lives at the home root, not inside the hoard.
- **Proved:** `host :8437 -> 200` and
  `{"ok":true,"db":"/home/craigema/Documents/Ymir/smidja/smidja.db","journal_mode":"wal","sessions":1}`,
  with the UI served from the visualizer's `dist`.
- **The same defect is still in a sibling, and is named rather than quietly left:**
  `bin/smidja-board.sh` (lines 46-49) carries the identical `${YMIR_HOME:-$HOME/
  Documents/ymirhome}` fallback. It is under `bin/smidja*`, a governed path whose asset
  is `smidja.md`, and the asset must be loaded before that edit. Recorded here so it is
  not lost.

galdr-reread: `smidja.md` (the smithy's board, before mending `bin/smidja-board.sh`).

### Files
- `scripts/start.sh`

## 2026-09-17 — 0.1.8: the day's work reaches npm

- **The doors.** `ymir` now carries the operator's verbs, each named for the
  figure who does the work: `raise` · `lower` · `eir` (heal) · `groa` (renew) ·
  `heimdall` (the way in) · `invite` · `smidja` (the board) · `hlidskjalf` ·
  `sessrumnir` · `mimir` · `sense` · `plan`. Before this, the package put two
  commands on PATH and neither could raise the app or the board.
- **The cloth.** `bin/ymir-style.sh` — colour and marks cut from the halls' own
  tokens (bone · bronze · steel · blood), shown only where a human watches, with
  the data left as TOON on stdout. The plan, the installer, the validate report
  and Eir all wear it.
- **The shapes.** `bin/smidja-lib.sh` tells a clone's smithy from a packaged one;
  `bin/smidja-board.sh` is the board's own door (`ymir smidja`), built and served
  from an npm install; `bin/electron-lib.sh` verifies a shell's runtime so a
  skipped npm install script cannot pass as a launch.
- **The icons.** One truth where three maps disagreed, and no claim of a glyph
  nobody drew: Óðrerir wears ansuz, Sessrúmnir othala, the smithy's icon is named
  for the smithy.
- **The repair.** `4dd7273`'s hand-merge left `bin/ymir-install.sh` and
  `scripts/start.sh` unparseable on main; both restored. Every runtime script
  parses again.

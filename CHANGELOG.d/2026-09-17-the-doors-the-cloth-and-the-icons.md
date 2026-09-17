## 2026-09-17 — the doors, the cloth, and the icons that were not there

Four things the operator met and could not use: doors that never opened, output
with no design, a board that could not be built from a package, and an icon map
that named a glyph nobody had drawn.

- **The doors are named for the figure who does the work.** `ymir` put two
  commands on PATH and could neither start the app nor raise the board. It now
  carries the doors: **raise · lower · eir** (heal) · **groa** (renew) ·
  **heimdall** (the way in) · **invite** · **smidja** (the board) ·
  **hlidskjalf** · **sessrumnir** · **mimir** · **sense** · **plan**. A name the
  law has not given a home — `doctor`, `validate`, `auth` — still answers, once,
  with the name that has it.
- **The cloth: `bin/ymir-style.sh`.** Ymir had correct output and no design. The
  palette is cut from the halls' own tokens — bone for words, bronze for what
  acts, steel for what stands, blood for what is wrong — with a mark per state
  (`◆ · — ✕ ? ✓`). Colour and marks appear only where a human is watching
  (stderr a TTY, `NO_COLOR` unset); the data on stdout stays TOON, and **the
  words are never conditional, only the colour is**. The plan renders in the
  cloth on stderr while the TOON stays pipeable; the installer opens with it and
  ends with the next steps.
- **The packaged tree is told apart from a clone.** `bin/smidja-lib.sh` resolves
  the smithy — `apps/smidja-factory` in a clone, `node_modules/@zerwiz/smidja-factory`
  in a package — and four call sites that assumed the clone now resolve through
  it. `bin/smidja-board.sh` is the board's own door (`build · start · stop ·
  status`), which `ymir smidja` runs; built and served end to end from an npm
  install: `{"ok":true,"sessions":1}`, `GET / → 200`.
- **A shell's runtime is verified, never assumed.** npm gates install scripts, so
  a skipped Electron postinstall leaves a partial runtime that still builds the
  web app and still reports success. `bin/electron-lib.sh` answers `ok · partial
  · absent`, the plan's `electron` row says **PARTIAL** with the exact remedy, and
  `step_desktop` refuses to claim a launch it cannot make.
- **The icons now name glyphs that exist.** Three maps disagreed: `runes.md` gave
  Óðrerir the rune `wunjo` — **a glyph nobody had drawn** — and tinted Sessrúmnir
  with a violet that is not in the tokens; `icons.md` gave `othala` to Óðrerir
  *and* Sessrúmnir; `design-icon.sh` minted `valhalla` for Óðrerir. One truth now:
  **Óðrerir → ansuz** (Odin's breath, the mead of poetry — what Óðrerir *is*),
  Sessrúmnir → othala, Valhalla keeps `ᚹ` (drawn in `valhalla.svg`, named Wunjo),
  Sowilo no longer claimed twice, every tint a house accent from the tokens, and
  the smithy's icon named `ymir-smidja` rather than `ymir-visualizer`. All 22
  glyphs parse; every claim resolves to a file. `docs/design.md` stopped calling
  a living map *"to create"*.

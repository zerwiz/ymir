
## 2026-09-17 — the sweep, and the door that mends itself

- **A retired name is swept from the launcher.** `ymir-visualizer.desktop` and its
  icon pointed at a glyph nobody ships — a blank square for anyone who knew the old
  name. `design-icon.sh install` removes retired entries now (`ymir-visualizer`,
  and `ymir-hlidskjalf-mobile` where that app is not installed).
- **`ymir hlidskjalf` mends the Electron runtime itself.** npm gates install
  scripts by default, so a fresh install can build the web app perfectly and have
  no window. The door now runs the repair it used to *describe*
  (`npm install-scripts approve electron` + `npm rebuild electron`), and only then
  refuses — with both the manual command and the honest alternative
  (`ymir install --no-desktop`).
- **Two faults are provably in the app repos, not here** (recorded so nobody hunts
  them in Ymir again):
  - **the fourth hall** — the landing's list is a hardcoded SPA component
    (`HallsSwitcher`; the bundle says *"three halls of Ymir — one seat, three
    roofs"*), not data from the gate API. Óðrerir must be added in
    `zerwiz/hlidskjalf` and the SPA rebuilt.
  - **the ember glow** — the seat ships `emberBootTheme` in its built renderer but
    no themed cloth beside it; the house's framework-neutral
    `midgard/design-system/ember.js` exists precisely so every surface can share
    one fire, and the seat must be told to light it (`zerwiz/sessrumnir`).

## 2026-09-17 — "not again", and four surfaces in one raise

- **Every notice can be silenced.** A line is information once and noise the
  tenth: the version that moved, the long-hour words, the next-steps block, the
  hints. Each now says so **once** in the cloth's faint voice — *not again:
  `ymir config notice version off`* — and the preference is recorded in the
  operator's settings, honoured by the shell cloth and the CLI alike. `ymir config
  show` is the door; four keys: `version · patience · next · hints`.
- **The package carries the design system.** It never shipped `midgard/`, so the
  rune glyphs — the icons themselves — were absent and every mark failed with
  *no glyph ansuz*. `midgard/design-system/` is in `files[]` now: 30 files, 22
  glyphs.
- **The marks are written in the right order.** The apps' own launcher templates
  landed *after* the rune marks and overwrote the themed name with an absolute
  `.png`; the templates go first now and the rune marks stand over them.
- **Óðrerir rises from a package.** Its published tarball carries `dist` and a
  `dev` command that calls a script it does not carry, so `npm run dev` could never
  work from a package — the hall serves its **build** (`astro preview`) where there
  is one, exactly as the SPA does. And its dependencies' absence is no longer
  silent: the hall says what failed and why.
- **Four surfaces, one raise.** `ymir raise` lifts the SPA, Óðrerir, the board and
  Sessrúmnir together; the installer's desktop step opens **one window per
  surface**, not a single "both".
- **A library must not end a function on a failing test.** `style_init` did, and
  `scripts/start.sh` runs under `set -e` — so the cloth took the whole raise down
  with it, silently. `return 0`, and the reason is written beside it.

## 2026-09-17 — 0.1.10: the hall answers on its port, and the marks land

- **The SPA listens where it is asked.** A bare `npm run dev` let Vite take 5173,
  so `:3888` answered nothing in either shape; a packaged tree now serves its built
  `./dist` and every shape passes `--port "$HLIDSKJALF_PORT" --strictPort`.
- **Óðrerir resolves** through `bin/app-lib.sh` instead of the clone's `apps/`.
- **The launcher entries and rune icons land on any Linux desktop** — the
  freedesktop half of desktop integration is no longer behind Omarchy's gate, so a
  GNOME operator gets marks at all.
- **The version a user went from and to** is said once, on the first run after an
  update: *the tree moved 0.1.9 → 0.1.10*.

## 2026-09-17 — npm-only: the hall answers on its own port, and the marks land on any desktop

The Allfather turned off every service running from the clone and asked for the
npm path alone to be true.

- **The SPA never listened on `:3888`.** `scripts/start.sh` raised it with a bare
  `npm run dev`, so Vite took 5173 — then 5174 — while `ymir-validate.sh` and
  every door looked for `:3888`. The port is now our decision
  (`--port "$HLIDSKJALF_PORT" --strictPort`), a packaged install serves its built
  `./dist` through `vite preview` instead of a dev server, and the raise prints
  the last lines of the log when the port does not answer instead of claiming
  success.
- **Óðrerir was skipped on a packaged install** — `HALL_DIR="$ROOT/apps/odrerir"`,
  the clone's layout again. It resolves through `bin/app-lib.sh` now
  (`app_dir odrerir`), like every other surface.
- **The launcher entries and the icons are the freedesktop half, not Omarchy's.**
  Both halves of `bin/desktop-place.sh` sat behind the Omarchy gate, so a GNOME
  operator got *nothing* — no entries, no rune icons — which is why the desktop
  marks from the clone existed and the ones from npm never appeared. `entries` is
  its own verb now (any Linux desktop), the installer's `marks` step calls it, and
  the desktop database and icon cache are refreshed afterwards.
- **A user can see what moved.** `npm install -g` says *"changed 266 packages"* and
  no versions. The CLI records the version it last ran and says the transition
  once: *the tree moved 0.1.7 → 0.1.9 · run `ymir eir` to see what stands*.

## 2026-09-17 — the doors, written down where a user will find them

- **`README.md` gains "After it installs — the doors"**: the two commands on PATH,
  the twelve doors on `ymir`, the lawless name that answers once and points at the
  lawful one, the patience words in full, and a section on **both shapes** — a
  clone and a package, with one resolver and one rule (colour for the eye, TOON
  for the pipe).
- **The skills that must know are taught.** Galdr's `assets/installation.md` gains
  the shape table, the eighteen converted call sites, and the trap that named
  itself (`printf -v` writes to the function's scope — scratch names are
  function-prefixed for that reason). The `ymir-host` skill's `assets/install.md`
  gains the doors and how to exercise the *other* shape without a second machine
  (`YMIR_ROOT_DIR`). The `groa-update` skill gains the step that matters after
  every update: **re-check where the apps live** — a shape assumption is a bug
  that only shows itself on the other shape — and say the long hour in the house's
  voice.

## 2026-09-17 — 0.1.9: both shapes reach the registry

- **`ymir raise` works on a packaged install.** 0.1.8 shipped before the resolver,
  so a user who installed from npm hit `cd …/apps/hlidskjalf: No such file or
  directory` — every package had arrived, and eighteen scripts were looking in the
  clone's `apps/`. `bin/app-lib.sh` resolves a surface in either shape now.
- **A clone and a package are one tree to the scripts.** Proven against both: the
  five surfaces resolve from `/home/zerwiz/Ymir` and from an npm-installed
  package, and `ymir raise` against a packaged tree fetches the app's
  dependencies, raises the gate API, starts Nornir cron, and brings up Bifrost and
  the well.
- **The patience words** — `style_patience` — open the installer's long chain and
  the raise path's build, so a long hour says what it is doing.

## 2026-09-17 — both shapes: a clone and an npm install, and the patience words

- **`ymir raise` failed on a packaged install** — and the reason was ours, not
  npm's. Every package had arrived; the scripts looked for the apps in the clone's
  `apps/`, where a package keeps nothing. `scripts/start.sh` died on
  `cd …/apps/hlidskjalf: No such file or directory`. **Eighteen files assumed the
  clone's layout.**
- **One resolver, both shapes:** `bin/app-lib.sh` — `apps/<surface>` in a clone,
  `node_modules/@zerwiz/<package>` in a package, with the surface→package map
  (`smidja` → `@zerwiz/smidja-factory`). Wired into the raise path, the windows,
  the invite door, the seat-hall, Eir, the icons, the placement, the hall snapshot
  and the installer's own SPA and shell steps. `bin/smidja-lib.sh` delegates to it
  now, so there is one truth about where things live.
- **Proven in both trees**: all five surfaces resolve from `/home/zerwiz/Ymir`
  (a clone) and from an npm-installed package. And `ymir raise` run against the
  packaged tree no longer dies — it fetches the app's dependencies, raises the
  gate API, **starts Nornir cron**, and brings up Bifrost and the well.
- **A trap worth naming:** `printf -v <name>` writes to the *function's* scope, so
  a helper whose scratch variable shares the caller's requested name swallows the
  answer. Every scratch name in the resolvers is function-prefixed for that
  reason.
- **The patience words.** A long install should say what it is doing and why it
  takes a while. `style_patience` — the cloth's own line — now opens the
  installer's long chain and the raise path's build:
  *much moves · the halls are being set right · this hour is long, and nothing of
  yours is lost in it — roots come home, shapes are re-cut, names are set true
  again. Your patience is noted, and it is earned.*

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

## 2026-09-17 — main is repaired, and the report wears the cloth

- **Main was broken and nobody had noticed.** A merge resolved by hand
  (`4dd7273`, from a parallel branch) kept *both* sides of a conflict in
  `bin/ymir-install.sh` and `scripts/start.sh`: a stray `<`, a duplicated step
  line, orphaned comments, an `if` with no `fi`. The installer could not parse at
  all — `bash -n` failed on main — and PR #53's merge carried the breakage
  forward. Both files are restored from the last revision that parses (`5b7fc66`),
  with the two fixes that revision predated re-applied: the `--phase` value is
  consumed, and `--yes | --non-interactive | --accept-all-defaults` are one thing.
  Every runtime script parses again; the installer's plan runs.
- **The lesson worth keeping:** a merge is not a place to guess. When both sides
  of a conflict are real, the resolution is a decision — and `bash -n` on every
  runtime script is cheap enough to be part of it.
- **The validate report wears the cloth** — the same rows rendered for the eye on
  stderr (marks, colour, and a verdict with the next step) while the TOON stays
  the data on stdout. It found real drift while it was being written: the SPA down
  on `:3888`, Nornir cron stopped, `sessrumnir`, `mcp` and `hoard` broken.
- **Eir watches the shells.** A new surface reports the desktop shells' runtime
  through `bin/electron-lib.sh` — a *partial* Electron runtime is exactly the
  quiet failure Eir exists for — and her rows render in the cloth too.

## 2026-09-17 — the house gains an unpublish door

- **`bin/npm-publish.sh --unpublish @scope/name@<version>`.** Publishing had a
  door in this house and unpublishing had none, so the act was done by hand on a
  machine whose `~/.npmrc` holds a stale token — the very reason the door exists.
  The new mode resolves the token from the hoard exactly as publishing does,
  demands a spec that names the version (a whole package is not a one-word act),
  supports `--dry-run`, and says plainly that the registry's CDN may serve the
  tarball for a while after the removal.
- **The window is 72 hours.** npm allows one version back within 72 hours of its
  publication; past that only npm support can remove it. The help text says so,
  because a door that does not name its own clock invites a late knock.
- **`@zerwiz/ymir@0.1.5` was unpublished** — the version that carried the memory
  well. Publishing the clean 0.1.7 moves the `latest` tag off the tainted build at
  once, which is the half of the repair that does not wait for propagation.

## 2026-09-17 — the plan learns the smithy's package name, and the install forwards its flags

Two defects the first real end-to-end npm install surfaced — which is what an
end-to-end test is for.

- **A surface's name is not its package's name.** The plan looked for
  `apps/smidja` or `@zerwiz/smidja`, but npm serves the smithy as
  `@zerwiz/smidja-factory` — so the row read `BLOCKED` on a machine where the
  smithy was installed and standing. `app_dir`/`app_row` now take the surface
  name and the package name separately, and the row tells the truth: installed,
  with the visualizer's UI still to build (the tarball ships its source, never a
  stale build).
- **`ymir install --plan` forwarded only `--json`.** `--phase` and `--blocked`
  were dropped on the way through the installer's door, so `--blocked` answered
  *unknown flag*. Every plan flag is forwarded now.

**The install this came out of:** `npm install -g @zerwiz/ymir` from the registry
— `@zerwiz/ymir@0.1.7`, 331 packages, and all four surfaces
(`hlidskjalf` · `odrerir` · `sessrumnir` · `smidja-factory`) arrived inside the
distro. The tarball carries no memory store — the leak is closed in the artefact
as well as in the repo.

## 2026-09-17 — the package shipped the memory well (one version, now excluded)

- **The exposure.** `@zerwiz/ymir@0.1.5` carries five files that are nobody's but
  the operator's: `.agents/memory/kaia.engram`, its `-shm` and `-wal` sidecars, and
  `.agents/memory/well/{episodes,workspace}.jsonl`. A public npm tarball contained
  the live memory well — the store and the episodes. Verified by fetching the
  published artefact and listing it; `0.1.0`–`0.1.4` are clean, and this branch's
  build is clean.
- **The cause, and it is a trap worth naming.** `.gitignore` excludes
  `.agents/memory/kaia.engram*` and `.agents/memory/well/*.jsonl`, and the repo is
  clean — but **npm does not consult `.gitignore` when `files[]` names a whole
  directory.** `files: [".agents/"]` packs that subtree *including* the ignored
  files. Nothing warned: the leak travelled in the artefact, not the repo.
- **The fix.** The manifest excludes them explicitly, because a `files[]` list
  cannot rely on the ignore file it overrides:
  `!.agents/memory/kaia.engram*`, `!.agents/memory/well/*.jsonl`,
  `!.agents/memory/*.db`, plus `!**/__pycache__/` and `!**/*.pyc` for the compiled
  junk that was travelling the same way. Verified: `npm pack --dry-run` carries
  864 files and **no** memory store — the memory README and the ledger's scaffold
  header are all that remain, as they should be.
- **The rule for every future package:** a `files[]` entry that names a directory
  overrides `.gitignore` for everything beneath it. Name what ships, or exclude
  what must not — and verify with a dry-run pack, never by assumption.
- **Remediation.** `@zerwiz/ymir@0.1.5` should be unpublished (it is inside npm's
  window); the clean build publishes as 0.1.7 and supersedes it.

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

## 2026-09-17 — the house gains an unpublish door

- **`bin/npm-publish.sh --unpublish @scope/name@<version>`.** Publishing had a
  door in this house and unpublishing had none, so the act was done by hand on a
  machine whose `~/.npmrc` holds a stale token — the very reason the door exists.
  The new mode resolves the token from the hoard exactly as publishing does,
  demands a spec that names the version (a whole package is not a one-word act),
  supports `--dry-run`, and says plainly that the registry's CDN may serve the
  tarball for a while after the removal.
- **The window is 72 hours.** npm allows one version back within 72 hours of its
  publication; past that only npm support can remove it. The help text says so,
  because a door that does not name its own clock invites a late knock.
- **`@zerwiz/ymir@0.1.5` was unpublished** — the version that carried the memory
  well. Publishing the clean 0.1.7 moves the `latest` tag off the tainted build at
  once, which is the half of the repair that does not wait for propagation.

## 2026-09-17 — the plan learns the smithy's package name, and the install forwards its flags

Two defects the first real end-to-end npm install surfaced — which is what an
end-to-end test is for.

- **A surface's name is not its package's name.** The plan looked for
  `apps/smidja` or `@zerwiz/smidja`, but npm serves the smithy as
  `@zerwiz/smidja-factory` — so the row read `BLOCKED` on a machine where the
  smithy was installed and standing. `app_dir`/`app_row` now take the surface
  name and the package name separately, and the row tells the truth: installed,
  with the visualizer's UI still to build (the tarball ships its source, never a
  stale build).
- **`ymir install --plan` forwarded only `--json`.** `--phase` and `--blocked`
  were dropped on the way through the installer's door, so `--blocked` answered
  *unknown flag*. Every plan flag is forwarded now.

**The install this came out of:** `npm install -g @zerwiz/ymir` from the registry
— `@zerwiz/ymir@0.1.7`, 331 packages, and all four surfaces
(`hlidskjalf` · `odrerir` · `sessrumnir` · `smidja-factory`) arrived inside the
distro. The tarball carries no memory store — the leak is closed in the artefact
as well as in the repo.

## 2026-09-17 — the package shipped the memory well (one version, now excluded)

- **The exposure.** `@zerwiz/ymir@0.1.5` carries five files that are nobody's but
  the operator's: `.agents/memory/kaia.engram`, its `-shm` and `-wal` sidecars, and
  `.agents/memory/well/{episodes,workspace}.jsonl`. A public npm tarball contained
  the live memory well — the store and the episodes. Verified by fetching the
  published artefact and listing it; `0.1.0`–`0.1.4` are clean, and this branch's
  build is clean.
- **The cause, and it is a trap worth naming.** `.gitignore` excludes
  `.agents/memory/kaia.engram*` and `.agents/memory/well/*.jsonl`, and the repo is
  clean — but **npm does not consult `.gitignore` when `files[]` names a whole
  directory.** `files: [".agents/"]` packs that subtree *including* the ignored
  files. Nothing warned: the leak travelled in the artefact, not the repo.
- **The fix.** The manifest excludes them explicitly, because a `files[]` list
  cannot rely on the ignore file it overrides:
  `!.agents/memory/kaia.engram*`, `!.agents/memory/well/*.jsonl`,
  `!.agents/memory/*.db`, plus `!**/__pycache__/` and `!**/*.pyc` for the compiled
  junk that was travelling the same way. Verified: `npm pack --dry-run` carries
  864 files and **no** memory store — the memory README and the ledger's scaffold
  header are all that remain, as they should be.
- **The rule for every future package:** a `files[]` entry that names a directory
  overrides `.gitignore` for everything beneath it. Name what ships, or exclude
  what must not — and verify with a dry-run pack, never by assumption.
- **Remediation.** `@zerwiz/ymir@0.1.5` should be unpublished (it is inside npm's
  window); the clean build publishes as 0.1.7 and supersedes it.

## 2026-09-17 — the house gains an unpublish door

- **`bin/npm-publish.sh --unpublish @scope/name@<version>`.** Publishing had a
  door in this house and unpublishing had none, so the act was done by hand on a
  machine whose `~/.npmrc` holds a stale token — the very reason the door exists.
  The new mode resolves the token from the hoard exactly as publishing does,
  demands a spec that names the version (a whole package is not a one-word act),
  supports `--dry-run`, and says plainly that the registry's CDN may serve the
  tarball for a while after the removal.
- **The window is 72 hours.** npm allows one version back within 72 hours of its
  publication; past that only npm support can remove it. The help text says so,
  because a door that does not name its own clock invites a late knock.
- **`@zerwiz/ymir@0.1.5` was unpublished** — the version that carried the memory
  well. Publishing the clean 0.1.7 moves the `latest` tag off the tainted build at
  once, which is the half of the repair that does not wait for propagation.

## 2026-09-17 — the package shipped the memory well (one version, now excluded)

- **The exposure.** `@zerwiz/ymir@0.1.5` carries five files that are nobody's but
  the operator's: `.agents/memory/kaia.engram`, its `-shm` and `-wal` sidecars, and
  `.agents/memory/well/{episodes,workspace}.jsonl`. A public npm tarball contained
  the live memory well — the store and the episodes. Verified by fetching the
  published artefact and listing it; `0.1.0`–`0.1.4` are clean, and this branch's
  build is clean.
- **The cause, and it is a trap worth naming.** `.gitignore` excludes
  `.agents/memory/kaia.engram*` and `.agents/memory/well/*.jsonl`, and the repo is
  clean — but **npm does not consult `.gitignore` when `files[]` names a whole
  directory.** `files: [".agents/"]` packs that subtree *including* the ignored
  files. Nothing warned: the leak travelled in the artefact, not the repo.
- **The fix.** The manifest excludes them explicitly, because a `files[]` list
  cannot rely on the ignore file it overrides:
  `!.agents/memory/kaia.engram*`, `!.agents/memory/well/*.jsonl`,
  `!.agents/memory/*.db`, plus `!**/__pycache__/` and `!**/*.pyc` for the compiled
  junk that was travelling the same way. Verified: `npm pack --dry-run` carries
  864 files and **no** memory store — the memory README and the ledger's scaffold
  header are all that remain, as they should be.
- **The rule for every future package:** a `files[]` entry that names a directory
  overrides `.gitignore` for everything beneath it. Name what ships, or exclude
  what must not — and verify with a dry-run pack, never by assumption.
- **Remediation.** `@zerwiz/ymir@0.1.5` should be unpublished (it is inside npm's
  window); the clean build publishes as 0.1.7 and supersedes it.

## 2026-09-17 — the smithy's dependency names the package npm will actually serve

- **`@zerwiz/smidja` is published and not served.** npm accepted it twice (0.1.0,
  then 0.1.1): the tarball and the version document existed, the package document
  never did, and a republish of 0.1.0 was refused as *"previously published"*. The
  name answers `404`, the website `403`, while `@zerwiz/hlidskjalf`,
  `@zerwiz/odrerir` and `@zerwiz/sessrumnir` resolve normally and always have.
- **A second free name failed identically.** `@zerwiz/smidja-factory` was published
  and shows the same shape — version served, package document withheld. Two names,
  one behaviour, while packages published yesterday serve fine: the withholding is
  npm's, not the name's, and the CLI does not report it.
- **The distro depends on the name that can resolve.** `optionalDependencies` now
  names `@zerwiz/smidja-factory`, so the moment npm serves that package the smithy
  arrives with the rest. Being optional, it is skipped silently until then — the
  plan's phase-5 row is what says so out loud.
- **`@zerwiz/ymir` 0.1.7** — the version published once this lands.

## 2026-09-17 — the four surfaces arrive by npm, and an old tree gives up what it holds

- **The app packages arrive with the distro.** `@zerwiz/ymir` now depends on the
  surfaces as their own packages — `@zerwiz/hlidskjalf`, `@zerwiz/odrerir`,
  `@zerwiz/sessrumnir` (live on the registry) and `@zerwiz/smiddja` (published at
  0.1.0 today). They are **optionalDependencies**, deliberately: a broken app
  package must never stop the core from installing, and a package not yet on the
  registry is skipped by npm and starts arriving the moment it is published.
  **Proven**: a global install from the packed tarball lands the core plus all
  three live apps, 330 packages, and the bin answers `0.1.6`. A local install
  hoists them to `node_modules/@zerwiz/<app>`; a global one nests them under the
  distro's own `node_modules` — the plan checks both shapes.
- **The plan tells the shapes apart.** "Declared as a dependency but not fetched"
  is a `DO`; "no package and no dependency" is a `BLOCKED`. All four surfaces read
  `DO` on a machine that has the distro but not yet the apps.
- **Migration 0005 — the operator's things leave the code tree.** It carries this
  machine's records, the runtime state (pids · logs · locks · the applied-marker),
  the operator's credentials, and the settings git does not track. Run on the
  Allfather's machine: **44 carried, 3 stale twins kept, 1 identical duplicate
  removed, 0 refused** — the tree left holding `.gitkeep` and the distro's own
  tracked defaults.
- **A collision is decided by evidence, never assumption.** Two files, one name:
  identical content means the tree's copy goes (the content is provably at home);
  different content means both are real, so the home's keeps the name and the
  tree's is carried beside it as `<name>.stale-<UTC>`. Never merged, never
  discarded. A template is not only `*.example` — `agents.machine.example.yaml`
  matched none of the old guards and was carried off as if it were the operator's;
  it is back, and the pattern now covers `*.example.*`.
- **The plan's `purity` row applies the same law.** A settings file git *tracks* is
  the distro's shipped default, not the operator's — and the check asks git about
  the real path, because the tree's `config` is a symlink into `.agents/config`
  and the index holds the real name. Asking about the link reported "untracked" and
  flagged the distro's own `cron.yaml`. It now reads: *nothing of the operator's is
  written into the code tree*.
- **`bin/npm-publish.sh --all` learns the smithy** — the registry maps `smidja` to
  `apps/smidja-factory`, so it is a publish target like any other app.
- **The smithy gets a front page.** `zerwiz/smidja`'s README was a three-line stub;
  it now says what Smíðja is, how to install it, how to run the visualizer on
  `:8437`, what the tree holds, and the shape of a run. The tarball also carries
  `LICENSE` and `NOTICE` — npm attaches the licence and the readme on its own, but
  **not the notice**.

## 2026-09-17 — the install asks with a plan, and the operator's things leave the code tree

- **The consent a real install asks for is now computed, not recited.** The old
  prompt was a hardcoded paragraph, and a paragraph cannot know the host: it named
  an Omarchy version on a Mac, promised a workspace tree that already stood, and
  never mentioned that no application had been installed at all. `bin/ymir-plan.sh`
  probes this machine and prints one row per step with its state and the reason —
  `DO · SKIP · INFO · BLOCKED · CONSENT` — across nine phases (resolve · code ·
  home · runtimes · engines · apps · wire · raise · verify). `ymir-install.sh`
  prints it at the consent prompt; `--plan` / `--dry-run` prints it and writes
  nothing; `--json`, `--phase N` and `--blocked` are there for automation and for
  reading what is holding an install back.
- **The four app surfaces are named in the plan.** hlidskjalf, odrerir, sessrumnir
  and smidja each get a row: whether the source is present, whether the web build
  exists, and — when it is absent — the honest reason (`no apps/<name> and no
  @zerwiz/<name> package`). The Electron shells are a `CONSENT` row, not a silent
  download: three shells each pull a ~100 MB runtime the web surfaces do not need.
- **The home is the operator's to choose.** `step_home` asks once, records the
  answer as machine state under `~/.config/ymir/home`, and every later script
  resolves it through `bin/hoard-lib.sh` (`$YMIR_HOME` → the recorded choice → one
  documented default). `--check` never writes; `--yes` takes what is recorded.
- **The roots law, applied across the tree.** The package is the **code that runs
  the programs**; everything the operator owns lives in the home. Two resolvers
  were added (`hoard_data_dir`, `hoard_state_dir`, `hoard_settings_dir`,
  `hoard_local_env`) and **42 call sites** converted: `$ROOT/data` and
  `$ROOT/state` (25 scripts), then `$ROOT/.env.local` and `$ROOT/config/*`
  (17 scripts). A credential no longer sits in a tree that ships, and machine
  records no longer sit where npm will erase them on upgrade.
- **The plan is the ward for that law.** Its phase-1 `purity` row names anything of
  the operator's found in the code tree — `data/`, `state/`, `config/*.yaml`,
  `.env.local` — so drift is reported on every run instead of discovered after an
  upgrade.
- **The install no longer lectures about local models.** The `step_models` console
  line told the operator to "load the modeltesting skill" — a skill that does not
  exist anywhere in the tree — mid-install. It is gone; the real method is named in
  the one place it belongs, the Galdr asset `assets/local-models.md`. `step_models`
  still ensures the Pi harness and seeds `~/.pi/agent/models.json`.
- **The package no longer claims to ship `config/`.** `config` is a symlink to
  `.agents/config`, which npm cannot carry; the tarball now declares what it
  actually contains (147 bin scripts, the agent-set template under `.agents/`).
  Settings are seeded into `$YMIR_HOME/config/agents.yaml` from the tracked
  template, falling back to `.agents/config/` when the symlink is absent.
- **A corrupted TOON block in `AGENTS.md`** — `outputs[7]` carrying eight rows and
  duplicate `midgard/` lines — is mended; the compliance gate reports 84 valid
  blocks again.
## 2026-09-17 — the registry says where a repo lives and what it is for

- **A project entry can now name its machine.** `machine:` records the host
  where a checkout lives; `data/machines.md` holds the fleet (omarchy-1,
  zerwiz, zerwizserver live on the tailnet). A repo is no longer assumed to be
  on the box you happen to be standing on.
- **A project entry can now say what it is for.** `about:` is one plain
  sentence per repo. `bin/project-git.sh list --field about` prints the whole
  inventory without opening the YAML.
- **`project-git.sh` resolves more of the block.** `--field` now accepts
  `machine`, `company`, `workspace` and `about` alongside the git fields, and
  non-git keys read from the project block rather than the `git:` line.
- **One registry, not two.** The live registry is `hodd/identity/projects.yaml`
  (what the runtime reads). A stale duplicate at `Documents/Ymir/identity/` had
  been drifting apart from it — different GitHub owners, different project sets
  — and is retired, with a backup kept in `hodd/state/`.

## 2026-09-17 — the private home gets the ward it never had

- **Six guards watched the public repo; the home had none — yet the home is where
  every private byte lives.** The one real leak of this day (`platform.env.prev-fill`,
  44 credentials) happened *there*, in a scratch backup swept up by `git add -A`,
  with nothing watching. `bin/hoard-guard.sh` closes that.
- **It is a hook, not a script.** Seated as `$YMIR_HOME/.git/hooks/pre-commit`,
  **git runs it on every commit** — including one made in a hurry, by a loop, or by
  an agent that has never heard of it. Verified by attempting a real `git commit`
  with no guard invoked: git refused, exit 1.
- **It catches what actually leaked**, verified by planting each: a scratch-backup
  name (`*.prev-*`, `*.bak`, `*.orig`), a plaintext secret filename, a secret shape,
  and — the evasion that would have hidden a key — **a base64 blob whose decode
  contains a PEM header**, under an innocent filename.
- **`bin/ymir-install.sh` seats it at both repos** (the `hoard-gate` step reports
  the home separately, so a dormant vault is visible), on every install layer.
- **A bypass is logged, not silent.** `hoard-guard.sh --log-bypass` appends to the
  Runes ledger when a `--no-verify` commit is detected.
- **Two stale flat paths fixed in the guards themselves.** `bin/docs-guard.sh` told
  an operator to move private docs to `$YMIR_HOME/docs/` — a path that no longer
  exists — and `bin/groa-update.sh` read `$YMIR_HOME/data/eindri-homes.md` instead of
  the hoard's. A guard pointing at the wrong door teaches the drift it exists to stop;
  `groa-update.sh` now resolves through `hoard_root`.

## 2026-09-17 — the NorthStar gate runs nightly; the platform door it caught is mended

- **`bin/nornir-job-nsr-compliance.sh` (02:30)** runs every
  `.compliance/gates/check_*.sh` (danger · env · paths · platform · wiring)
  and carves the verdict — `nsr.compliance` clean, or `nsr.compliance.failed`
  (exit 1) naming the broken gate, so the 07:00 briefing reads it at sunrise.
- **The gate it caught, mended:** `scripts/electron.sh` used `kill -9`, which
  the platform gate rightly refuses as non-portable. It now uses `kill -KILL`
  (the house idiom already in `scripts/stop.sh`) — the NSR round is 5/5 green.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md` — new
§3.5 (hall snapshot) and §3.6 (NSR round) rows.

## 2026-09-17 — the Live Hall's board becomes true: the snapshot lands on the loom

- **The Hall was a glass with nothing behind it.** The Óðrerir page reads
  `apps/odrerir/public/livehall.json` same-origin, but nothing wrote it on a
  schedule — the board showed the saga's own static count and said so.
  `bin/nornir-job-hall-snapshot.sh` (08:00, after the 06:00 observer and the
  07:00 briefing) now drives `bin/hall-snapshot.sh` from real state — runes,
  projects, the cron gauge, the wake queue, standing smiths, armed when-
  sources, landed errands — and carves Rune `odrerir / hall.snapshot`.
- The snapshot is runtime, never repo: `apps/odrerir/public/livehall.json` is
  gitignored, so the job never dirties a branch.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md` — new
§3.5 row (reads/writes table, idempotence note).

## 2026-09-17 — the hoard gets a guard, and Rule 04 stops contradicting the disk

- **Eir gains a `hoard` surface.** Private data drifting outside the hoard is
  now caught rather than discovered by asking "where did that go?". The check
  fails on two things: a `.ymir-layout.yaml` entry naming a directory that does
  not exist (a stale map is what lets private work land outside the hoard), and
  a flat `$YMIR_HOME/{identity,data,docs,secrets,tenants}` sitting beside
  `hodd/`. `fix` merges a flat duplicate into the hoard without clobbering, then
  repoints any stale layout entry at the hoard.
- **Rule 04 corrected, append-only.** The rule's mapping table read as if
  `hodd/x/` and `$YMIR_HOME/x/` were two locations; on a real home that produced
  two parallel stores which drifted. The appended correction states the truth:
  `$YMIR_HOME/hodd/` **is** the private data path, `bin/hoard-lib.sh` is the one
  source of truth for it, and `.ymir-layout.yaml` must name only paths that
  exist. Nothing above the correction was rewritten.

## 2026-09-17 — the hoard encrypts its secrets at rest

- **`bin/hodd.sh` decrypts transparently.** `load`, `emit`, and `tenant` now
  accept a plaintext file *or* an `.age` ciphertext with the sibling plaintext
  absent. A shared `resolve_secret` finds the readable form; when it decrypts,
  it uses a mode-600 temp and removes it afterward. An agent asks for the
  resolved path and never handles ciphertext directly.
- **Secrets stay encrypted at rest.** `hodd/secrets/platform.env.age` is the
  committed form; the plaintext is scratch and gitignored. Round-trip verified
  byte-identical before the plaintext was untracked.
- **The vault invariant, written down.** The age key and the ciphertext travel
  together in the private `ymirhome` repo, so a dead disk loses nothing — and
  `ymirhome` **must never be made public**. Stated in `hodd/docs/secrets-vault.md`.
- **The honest limit.** This is encryption-at-rest, not encryption-against-yourself:
  on a single-user machine, a process running as the operator can read what the
  operator can read. What it buys is the *file* and the *repo*, not the *account*.

## 2026-09-17 — the Forge speaks: each skill's own text in the index

- **The Forge listed skills as bare names.** `Forge.tsx` rendered only
  `{s.name}` + the aett rune, while the live `/api/skills` index carries every
  skill's `description` (240-char truncation) — the data was there, the
  surface never showed it. The skill list items are now two-line cards: name +
  aett on the head row, the description beneath (`forge-item-desc`, dimmed
  until hover), scoped to the skill variant so the Eindri rows keep their
  side-by-side name+status shape.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` — the
Forge gate bullet (skill list shows name + aett + description).

## 2026-09-17 — the feed follows Brokk's thinking past the composer

- **Sessrúmnir's auto-scroll never counted streamed THINKING as growth.**
  `useChatScroll` watched `messages` and `streamingContent` only, so a
  reasoning-heavy turn (thinking before any visible content) grew the feed
  without moving it — the thinking block ended up below the floating composer,
  behind it, and the Allfather had to scroll down to read it.
- **The growth signal now also includes `streamingThinking` and streaming tool
  calls.** While Brokk reasons, the feed keeps the thinking tail in view above
  the composer (still only when Auto Scroll is on and the reader is at the
  bottom — scrolling up to re-read never gets yanked).
- Live hall updated: rebuilt renderer delivered to the running Sessrúmnir and
  the app restarted via `bin/sessrumnir.sh` (window back on workspace 8).

## 2026-09-17 — the editor stops being banished to its own desktop

- **`bin/editor-place.sh` pinned the editor to its own desktop with
  `no_focus = true`** — VS Code mapped onto a different workspace than the one
  the Allfather worked on and never took focus, so nothing inside it was
  clickable. The rule was written by Ymir itself into
  `~/.config/hypr/ymir-desktops.lua`.
- **The editor is now UNMANAGED by default**: it opens on the active desktop,
  focused and clickable, like any other app. The old pin remains reachable
  explicitly with `YMIR_EDITOR_PIN=1 bin/editor-place.sh apply`.
- Live desk healed: the `code` windowrule was removed from
  `~/.config/hypr/ymir-desktops.lua` (backup kept alongside), Hyprland reloaded
  with no config errors, and the stranded VS Code windows were moved to the
  active desktop and focused.

## 2026-09-17 — models, providers, and paths are the user's — and the gate says so

- **The law, amended (Rule 07).** Two clauses appended, the rule itself untouched:
  - **A. Models and providers live in the hoard, per user, read from YAML.**
    Every operator's differ, so there is **no global model or provider** — a
    shipped default naming a model is a claim about someone else's machine. The
    user's own live in `$YMIR_HOME/hodd/`, read from a YAML file there; the repo
    ships a template.
  - **B. No hardcoded absolute file paths.** No `/home/<user>/…`, no
    `/Users/<user>/…`, no `C:\Users\…`. A path is relative to a resolved root or
    comes from env/config with one documented default.
- **The gate, `config`.** `compliance-check.sh` gains a check that fails on a
  model id or provider name used as a **value** in shipped code or a tracked
  config, and on an absolute path naming a user. Comments, `*.example` templates,
  `CHANGELOG*`, and `assets/reference/` are exempt by intent — they document,
  they do not configure. **192 files clean.**
- **Three real violations found and fixed:**
  - `.agents/config/eindri-dispatch.json` — three dispatch rules named
    `opencode-go/deepseek-v4.1-flash`. Now a template with `<your-model-id>`.
  - `.agents/skills/galdr-ymirsystem/assets/pi-boot/pi-profile.yml` — the PI boot
    profile named `lmstudio/qwen3.6-35b-a3b`. Now a placeholder.
  - `bin/bootstrap-macos.sh` — `/home/ubuntu/Documents/Ymir`. Now resolved from
    `YMIR_VM_USER` with one documented default.
- **Two false positives found and fixed in the gates themselves.** The `mocks`
  gate flagged a prose comment explaining why a guard exists; the new `config`
  gate first flagged a sentence mentioning `llama.cpp/llama-swap`. Both now
  exclude comments and require a value position — a gate that cries wolf is a
  gate that gets ignored.
- **Four pre-existing failures on main mended** so the gate could be added to a
  green tree: a duplicated `midgard/` row in `AGENTS.md` (a bad merge left three),
  the `mocks` false positive, `smidja-factory` indexed but app-provided, and the
  seat's cloth read from an app repo that is absent until `step_apps` runs
  (`design-check` now skips cleanly rather than failing every worktree).

## 2026-09-17 — midgard holds public assets only; the company wiki is gone

- **`midgard/company_wiki/` did not belong in this repo.** It was an empty
  placeholder (one `.gitkeep`), but a company wiki is *tenant data* — policies,
  vision, specs, client names — and this repo is public. Removed, with every
  reference to it corrected in `midgard/README.md`, `STRUCTURE.md`, `docs/lore.md`
  and `assets/Ymir.md`.
- **`midgard/` is now described precisely.** It was called "shared company
  assets" in one place and "cross-tenant" in another; a wiki is neither. The
  contract says **public assets**, and `midgard/README.md` names what does *not*
  belong: company knowledge, which lives at `$YMIR_HOME/hodd/identity/companies/`.
- **`bin/private-guard.sh` gains a tenant-document rule** so the shape cannot
  return: a `company_wiki/`, `wiki/`, `policies/`, `handbook/` or `vision`/
  `strategy`/`roadmap` document staged in the public tree is refused, with a
  message naming where it belongs. Verified by planting `midgard/company_wiki/policies.md`.
- **Nothing had leaked.** A full sweep of every tracked midgard file for personal
  handles, home paths, key shapes, tunnel UUIDs and LAN/tailnet addresses found
  no hits — the ingress configs use `${VARS}` and `example.org` throughout, and
  the DB schema is generic with row-level security on every tenant table.

## 2026-09-17 — AGENTS.md states the one law: no private data in the public repo

- **The law is now first.** A `first_law` block sits directly under the mandate
  in `AGENTS.md`: never store personal or private data in this repo — not a
  secret, a key, a name, a plan, a schedule, a client, a credential, or a note.
  The repo is public; private data lives at `$YMIR_HOME`, under `hodd/`.
- **The private-data section was rebuilt against the disk.** It had duplicated
  `secrets/` and `identity/` lines, no `hodd/` level, and a layout that no longer
  matched the home. It now shows the real tree, names `$YMIR_HOME/hodd/` as *the*
  private data path, and records that `bin/hoard-lib.sh` is the one source of
  truth for it.
- **Every `$YMIR_HOME/...` path in the file was corrected** to `$YMIR_HOME/hodd/...`
  — the directory rules table, the registry reference, the secrets reference, and
  the append-only ledger path all pointed at the old flat layout.
- **Two wards are now documented**: `bin/secret-guard.sh` (a secret entering the
  repo) and Eir's `hoard` surface (private data drifting outside the hoard, or a
  `.ymir-layout.yaml` naming a path that does not exist).
- **Staging discipline is written down.** Stage named files in the home, never
  `git add -A` — a scratch file written seconds earlier gets swept into a commit
  and pushed. This happened this day and cost a history rewrite.
- **`hodd/AGENTS.example.md`** carried the same stale flat paths and a wrong
  command (`secret-guard.sh emit`, which does not exist); both corrected.

## 2026-09-16 — the validator stops calling a dead visualizer healthy

`bin/ymir-validate.sh` reported `visualizer PASS "UI built and served on :8437"`
by looking at `./dist` alone. When the API had crashed on a bad `CMD_DB` and
nothing was listening on `:8437`, the validator still said PASS — the false-pass
class this night kept surfacing, in the very tool meant to catch it.

- **The check now probes the port as well as the build.** `dist` missing → FAIL;
  built but nothing on `:8437` → FAIL with the fix (`run scripts/start.sh`);
  built and listening → PASS. A PASS now means the thing is actually up.
- **The smidja-db check resolves the same DB pair** `scripts/start.sh` and
  `bin/smidja-bootstrap.sh` do (an existing `$YMIR_HOME/smidja/smidja.db` first,
  then an in-repo copy, `SMIDJA_DB` override) — previously it named the home path
  only, so an in-repo DB read as missing.
- `galdr-reread`: `assets/installation.md` — a `visualizer` PASS means built *and*
  listening.

## 2026-09-16 — the roster's effect lands, and the backend pin stops being committable

Applying the private roster (`bin/agents-config.sh apply`) writes the resolved
model into each agent's canonical profile. Flipping the two local agents to Pi
made that visible — and surfaced a small ignore hole.

- **Profiles follow the roster.** `sindri-developer.md` and `kvasir-scout.md`
  now carry their **Pi** ids (`llamacpp-coder/qwen3-coder-30b`,
  `llamacpp/qwen3.5-9b`), and `huginn-researcher.md` its declared model — the
  output of `apply` against the operator's roster. These profiles are what the
  harnesses load, so the local agents now run on Pi rather than through OpenCode.
- **`.agents/config/backend` is ignored.** The pinned terminal backend is
  machine-local, but `config` is a **symlink** to `.agents/config`, so the
  `config/*` rule never matched it and the pin was committable. The file is named
  in `.gitignore` instead.

## 2026-09-16 — the roster can finally run an agent on Pi

`bin/agents-config.sh apply` wrote **every** agent's model into `opencode.json`'s
agent block, whatever harness that agent used. So an agent set to run on **Pi**
(native local models) would have had its Pi model id —
`llamacpp/qwen3.5-9b` — written into OpenCode's config, which cannot resolve it.
That is why the roster's two local agents were pinned to `harness: opencode` with
opencode-style ids: there was no working way to put an agent on Pi.

- **`apply` is now harness-aware.** Only `opencode`-harness agents are written
  into `opencode.json`; a `pi` (or `hermes`) agent is left out, its model id going
  to the resolve cache that `bin/agent-run.sh` reads. The providers block is
  unchanged — a provider's endpoint is a real fact OpenCode may still want.
- The way this is meant to be used: declare a local agent's model as its **Pi**
  id (`llamacpp/qwen3.5-9b`, `llamacpp-coder/qwen3-coder-30b` — the ids `pi
  --list-models` reports) with `harness: pi`; the roster is then Pi-driven with no
  per-machine hand-editing.
- `galdr-reread`: `assets/harness-integration/README.md` — the two writers of
  `opencode.json`, and the rule that only OpenCode agents belong in it.

## 2026-09-16 — the mesh reaches Teams and Anchor, and `show` stops guessing

`bin/a2a-mcp.sh` wired only the well (`engram`) and the mesh (`a2abridge`). The
**Teams** plane and **Anchor** memory existed only in the operator's personal
harness config, so no agent *inside* Ymir could see tickets or anchored memory —
and `a2a-mcp.sh show` insisted on a **fixed** server list, reporting
`wayofteams-mcp not on PATH` even when the plane was wired and working.

- **Remote MCP servers, URL-driven.** `bin/a2a-mcp.sh` now wires `wayofteams`
  (from `WAYOFTEAMS_MCP_URL`) and `way-of-anchor-sse` (from `ANCHOR_MCP_URL`).
  OpenCode gets them natively (`type: remote`); Pi, which has no remote
  transport, gets them through the `mcp-remote` stdio bridge. A URL wins over a
  local `wayofteams-mcp` binary when both exist. The URLs are credential-ish and
  live in the private platform env — never the tracked tree.
- **`show` reports what is actually wired.** It enumerates every key present in
  Pi's `mcpServers` and OpenCode's `mcp` (union with what this run would add), so
  a hand-added or previously-installed server is visible, and the hint only fires
  when Teams/Anchor is genuinely absent.
- `galdr-reread`: `assets/harness-integration/README.md` — the MCP scope is now
  well · mesh · Teams · Anchor, with the two env keys named.

## 2026-09-16 — the credential reaches the gate, and the hall stops leaking an IP

Setting the operator password had **no effect**. This is the bug that made that
true, and the runtime state that leaked a private address.

- **`scripts/start.sh` never loaded the platform env for the gate.** The gate is
  `bun run apps/hlidskjalf/server/index.ts`, and the server reads
  `process.env.HLIDSKJALF_AUTH` — but the launcher passed only `PORT`, and nothing
  sourced `.env.local`. So a credential written by `bin/ymir-setup-auth.sh`
  (correctly: `0600`, gitignored) never arrived, and because the gate treats an
  empty `GATE_AUTH` as authenticated (`authed: GATE_AUTH ? … : true`) the gate
  stayed **open**. `start.sh` now loads `.env.local` once, before the ports, for
  every service it raises — the gate, Bifrost and Mimir.
- **`apps/odrerir/.astro/dev.json` was tracked.** Astro rewrites it on every
  start with the live `pid` and the host's own addresses (LAN + tailnet) — a
  private-IP leak into a public tree. It is now untracked and gitignored; the
  generated types beside it stay tracked.
- `galdr-reread`: `assets/hlidskjalf-ui.md` (the gate must receive the credential)
  and `assets/odrerir-hall.md` (`.astro/dev.json` is runtime state).

## 2026-09-17 — the fragment convention is enforced where GitHub runs it

- **The gap, found by doing it.** The pre-push hook folds fragments before a
  push — but a **GitHub merge bypasses the local hook entirely**. PR #43 merged
  and left its own fragment unfolded on `main`, so the ledger silently fell
  behind what the fragments already told. `bin/changelog-assemble.sh --check`
  catches exactly that state; nothing was calling it.
- **The gate, at the layer that runs.** `.github/workflows/ymir-changelog-fragments.yml`:
  - **on `push` to main** — `bin/changelog-assemble.sh --check` fails when any
    fragment is unfolded, so the ledger can never fall behind a merge.
  - **on a PR** — a change touching code or docs must add a fragment, edit
    `CHANGELOG.md`, or carry the `no-changelog` label. The label records the
    deliberate decision that no entry belongs, rather than letting it be
    forgotten.
- **The pattern is the standard one.** This is the well-trodden "news fragments"
  design (towncrier — Twisted, pytest, pip, attrs; changesets; CPython). The
  zeroc-ice proposal states the root cause exactly: *"PRs edit one shared file.
  Better merge discipline doesn't fix it; not editing the shared file does."*
- **`merge=union` was considered and rejected on evidence.** The Rigor ADR-105
  tried it and measured it: *"GitHub's PR-mergeability and merge computation
  ignore `.gitattributes` merge drivers, union included."* It works against local
  git and does nothing on GitHub — a trap already falsified.
- **Main's own pending fragment is folded in this change**, so the ledger and the
  fragments agree from here on.

## 2026-09-17 — the changelog stops conflicting: fragments, folded by a script

- **The problem, measured.** `CHANGELOG.md` is one file and every branch appends
  at the same position — the top. Git sees two branches inserting different lines
  at the same spot and calls it a conflict, so **every merge re-conflicts every
  open branch**. Sixteen open PRs were each resolved by hand for this reason
  alone, and each merge re-conflicted the rest: O(N²) meaningless conflicts.
- **The fix — `CHANGELOG.d/`.** A change adds **one file with a unique name**
  (`<YYYY-MM-DD>-<slug>.md`) instead of editing the ledger. Two branches never
  touch the same fragment, so the collision cannot occur.
- **`bin/changelog-assemble.sh`** folds fragments into `CHANGELOG.md` — newest
  first, above everything already recorded. Folding is an **append**: existing
  entries are copied verbatim, never reordered, never rewritten. `--dry-run`
  shows what would fold; `--check` exits 1 when fragments are unfolded.
- **The pre-push hook folds first.** `bin/changelog-guard.sh --install` now
  writes a hook that runs the assembler before the guards, so a push never leaves
  fragments unfolded; if folding changes the ledger the push is refused until the
  fold is committed.
- **The guard accepts either form.** A push satisfies the duty by appending to
  `CHANGELOG.md` **or** by adding a fragment. The refusal message now names both.
- **Rule 06 is amended, append-only** — the clause stands; the amendment records
  fragments, and `CHANGELOG.d/` joins the append-only set so a move must carry it.

## 2026-09-17 — the hearth re-seeds on its container: Sessrúmnir's chat fire returns

- **The ember glow was gone from the chat because the canvas sized itself once
  at mount and only re-seeded on `window.resize`.** Sessrúmnir's split panes
  (file tree · editor · image) resize the chat column without any window resize,
  so the hearth kept a stale or zero-sized canvas — invisible. Both the shared
  hearth (`midgard/design-system/ember.js`) and Sessrúmnir's React port
  (`ember-background.tsx`) now watch their container with a ResizeObserver and
  re-seed only when the measured size actually changes (never per-frame).
  Hlidskjalf inherits the same mend through the shared module.
- **Verified live**: Sessrúmnir restarted on the fresh build; a screen capture
  of the running window shows the fire drawing (ember + warm-glow pixels across
  the hearth area). The running app had been serving a stale bundle (missing
  `react-i18next` — deps installed, rebuilt).

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` — the
EmberBackground hearth section (shared module + ResizeObserver mend).

# CHANGELOG

## 2026-09-16 — a sandboxed worker cannot think: `auto` stops killing agents

Spawning an Eindri with the default `--isolation auto` produced an **empty pane
and no status line**. The cause: `auto` chose Utgard whenever the image existed,
and Utgard runs with `--network none` — so the worker could reach neither its
cloud model (OpenCode Go) nor a local one (llama.cpp) and died at launch, silently.

- **`auto` now keeps the worker in its worktree.** A spawned Eindri is a
  model-driven worker: it must reach a model endpoint to think. Utgard is for
  untrusted *code*, not for the agent's own brain, so the automatic choice is
  `off`, and it says why.
- **`--isolation on` warns loudly.** It stays available for a sandbox that can
  actually reach a model, but it now prints that Utgard has no network and the
  agent will die silently without one.

## 2026-09-16 — the roster's effect lands, and the backend pin stops being committable

Applying the private roster (`bin/agents-config.sh apply`) writes the resolved
model into each agent's canonical profile. Flipping the two local agents to Pi
made that visible — and surfaced a small ignore hole.

- **Profiles follow the roster.** `sindri-developer.md` and `kvasir-scout.md`
  now carry their **Pi** ids (`llamacpp-coder/qwen3-coder-30b`,
  `llamacpp/qwen3.5-9b`), and `huginn-researcher.md` its declared model — the
  output of `apply` against the operator's roster. These profiles are what the
  harnesses load, so the local agents now run on Pi rather than through OpenCode.
- **`.agents/config/backend` is ignored.** The pinned terminal backend is
  machine-local, but `config` is a **symlink** to `.agents/config`, so the
  `config/*` rule never matched it and the pin was committable. The file is named
  in `.gitignore` instead.

## 2026-09-16 — the roster can finally run an agent on Pi

`bin/agents-config.sh apply` wrote **every** agent's model into `opencode.json`'s
agent block, whatever harness that agent used. So an agent set to run on **Pi**
(native local models) would have had its Pi model id —
`llamacpp/qwen3.5-9b` — written into OpenCode's config, which cannot resolve it.
That is why the roster's two local agents were pinned to `harness: opencode` with
opencode-style ids: there was no working way to put an agent on Pi.

- **`apply` is now harness-aware.** Only `opencode`-harness agents are written
  into `opencode.json`; a `pi` (or `hermes`) agent is left out, its model id going
  to the resolve cache that `bin/agent-run.sh` reads. The providers block is
  unchanged — a provider's endpoint is a real fact OpenCode may still want.
- The way this is meant to be used: declare a local agent's model as its **Pi**
  id (`llamacpp/qwen3.5-9b`, `llamacpp-coder/qwen3-coder-30b` — the ids `pi
  --list-models` reports) with `harness: pi`; the roster is then Pi-driven with no
  per-machine hand-editing.
- `galdr-reread`: `assets/harness-integration/README.md` — the two writers of
  `opencode.json`, and the rule that only OpenCode agents belong in it.

## 2026-09-16 — the visualizer finds its DB, and the seat-hall actually builds

Two more readers left behind — both discovered by *starting the apps*, not by any
gate. Each failed silently in its own way.

- **`scripts/start.sh` pointed the smithy at a repo path that no longer holds the
  DB.** `0003-private-data-separation` moved it to `$YMIR_HOME/smidja/smidja.db`,
  but the starter still passed `CMD_DB=<repo>/apps/smidja/smidja_data/smidja.db`
  — so the visualizer API died on boot with `smidja.db not found` and `:8437`
  answered nothing. It now resolves the same pair `bin/smidja-bootstrap.sh` does
  (home first, in-repo fallback, `SMIDJA_DB` override). The asset already
  *described* this resolution; the code now implements it.
- **`bin/sessrumnir-ensure.sh` never built the app.** `[ "$built_present" ]` tests
  a **literal, non-empty string** — always true — so `ensure --install` skipped
  `build_app` and reported `built: no` with exit 0. Sessrúmnir only built when the
  build was run by hand. Now `built_present` (the function) is called.
- `galdr-reread`: `.agents/skills/galdr-ymirsystem/assets/smidja.md` — the DB
  path, the `scripts/start.sh` DB resolution, and the observer's read list.

## 2026-09-16 — the credential reaches the gate, and the hall stops leaking an IP

Setting the operator password had **no effect**. This is the bug that made that
true, and the runtime state that leaked a private address.

- **`scripts/start.sh` never loaded the platform env for the gate.** The gate is
  `bun run apps/hlidskjalf/server/index.ts`, and the server reads
  `process.env.HLIDSKJALF_AUTH` — but the launcher passed only `PORT`, and nothing
  sourced `.env.local`. So a credential written by `bin/ymir-setup-auth.sh`
  (correctly: `0600`, gitignored) never arrived, and because the gate treats an
  empty `GATE_AUTH` as authenticated (`authed: GATE_AUTH ? … : true`) the gate
  stayed **open**. `start.sh` now loads `.env.local` once, before the ports, for
  every service it raises — the gate, Bifrost and Mimir.
- **`apps/odrerir/.astro/dev.json` was tracked.** Astro rewrites it on every
  start with the live `pid` and the host's own addresses (LAN + tailnet) — a
  private-IP leak into a public tree. It is now untracked and gitignored; the
  generated types beside it stay tracked.
- `galdr-reread`: `assets/hlidskjalf-ui.md` (the gate must receive the credential)
  and `assets/odrerir-hall.md` (`.astro/dev.json` is runtime state).

## 2026-09-16 — four readers that still pointed at the pre-split world

The app split and the hoard migration moved things; four readers never followed.
None failed loudly — each reported a clean PASS, a wrong SKIP, or a silent loss.

- **`bin/ymir-install.sh` wrote during `--check`.** The step chain ran
  `bin/ymir-migrate.sh apply` unconditionally, so a preview that promises *"report
  only, no writes"* actually **moved private data**. Migrations now apply only on
  a real run: `if [ "$CHECK" = 0 ]; then ... apply; fi`.
- **`.agents/migrations/0003-private-data-separation.sh` skipped every directory.**
  It pre-creates its target dirs, then its `copy` refused any target that already
  existed — so `data/` (and every other directory source) was silently dropped.
  The realm declaration never arrived and `0004` fell back to a neutral realm.
  `copy` now **merges** a directory into its target (never overwriting a file) and
  copies a single file only when it is absent.
- **`bin/smidja-bootstrap.sh` looked for the smithy at the old root.** `sys.path`
  pointed at `smidja/`, but the split moved it to `apps/smidja/`, so the DB seed
  died with `ModuleNotFoundError: No module named 'smidja_modules'`. It now
  searches `apps/smidja` then `smidja`, so either layout works.
- **`bin/ymir-validate.sh` read the ledger from the pre-move path.** It looked at
  `$YMIR_HOME/memory/`, but `0004-hoard-and-realms` put the ledger at
  `$YMIR_HOME/hodd/memory/` — a false `runes FAIL` on a healthy home. It now tries
  the hoard first, then the pre-move locations.
- `galdr-reread`: `.agents/skills/galdr-ymirsystem/assets/smidja.md` — the
  protected-paths gotcha and the `smidja/` → `apps/smidja/` move.

## 2026-09-17 — Pi gets its agents, and a dead extension comes back

- **Pi has no agent loader.** Agent loading in Pi is a *package* (`pi-agents`,
  `pi-agent-mode`, `pi-simple-agents`), never a core feature — and Ymir installs
  none. So `.pi/agents/` held twenty correct profile links that **nothing in Pi
  ever read**. The same failure as OpenCode's singular `.opencode/agent/`,
  arrived at from the other side.
- **The fix ships in this repo, not a root-pi package.**
  `.pi/shared/extensions/ymir-subagents.ts` discovers the canonical
  `.agents/agents/*.md` tree itself and registers a `subagent` tool. A call runs
  the chosen figure as a nested model call in the current session: the figure's
  markdown body is its system prompt, its frontmatter `model:` picks the model
  where the machine serves it. `subagent({})` and `/subagents` list the roster.
- **It imports nothing.** `@earendil-works/pi-coding-agent` is not installed as a
  package, so an extension importing its types cannot load at all. This one takes
  `pi` as `any` and declares `parameters` as a plain JSON schema — the pattern
  every working extension in the tree already uses.
- **A rename that left a reader behind.** `skuld-branch-supervision.ts` imported
  `calmTranscriptClassIsVisible` / `CalmPresentationState` from
  `./lib/ro-visibility.ts`, but that module exports `roTranscriptClassIsVisible` /
  `RoPresentationState`. Pi refuses the **whole extension** at load, so Skuld's
  supervision branch was dead in every session and nothing reported it. Fixed.
- **The check that catches it** is now recorded in the owning asset: import every
  deployed extension with `node --input-type=module` and confirm it loads — a
  module that cannot resolve is invisible from the file listing.
## 2026-09-17 — every figure loads: the agent directory was never read

- **The bug, stated plainly.** Twenty agent profiles existed, twenty symlinks
  pointed at them, and every gate was green — yet OpenCode loaded **three**
  agents. The symlinks lived in `.opencode/agent/` (SINGULAR). OpenCode reads
  `.opencode/agents/` (PLURAL). Twenty correct links sat in a directory no loader
  opened, so only `brokk` and `hnoss` — the two declared by hand in
  `opencode.json` — ever appeared.
- **The directory is fixed and migrated.** `.opencode/agent/` → `.opencode/agents/`
  (20 links, all resolving). `bin/valknut-load.sh` now writes the plural path and
  **migrates a legacy singular dir forward**, so an old home heals instead of
  silently keeping its agents invisible.
- **The roster now declares what it names.** `bin/agents-config.sh apply` only
  touched an agent already present in `opencode.json` (`if a in ablock`), so a
  figure the roster knew but the config had never seen stayed undeclared. The
  roster is the source of truth; a name in it now reaches the harness config.
- **A new gate catches the class.** `compliance-check.sh` gains **`roster`**: the
  roster (`config/agents.yaml.example`) and the canonical tree
  (`.agents/agents/*.md`) must name the same figures. A figure in the tree but not
  the roster falls to `default_model` and is never declared; a figure in the
  roster with no profile is a phantom. This is the check that would have caught
  the real failure while every other gate stayed green.
- **Verified, not assumed.** `opencode agent list` in the worktree reports all
  twenty figures (bragi … vor) plus Ymir's own subagents — 33 agents, up from 3.
  Compliance: 14/14 PASS.
- **References swept.** Every `.opencode/agent/` reference in code and docs moved
  to the plural path: `bin/valknut-load.sh`, `bin/agents-config.sh`,
  `apps/hlidskjalf/server/index.ts`, `RULES/02-agents.md`, `README.md`,
  `docs/runbooks/agents.md`, `.pi/extensions/README.md`, and the Galdr assets
  (`harness-integration`, `runtime-compliance`, `registry`, `hlidskjalf-ui`).
  `CHANGELOG.md`'s own historical entry is left as written — append-only.

## 2026-09-16 — the core senses the real host, not Omarchy's shadow

- **`bin/ymir-install.sh` `step_host` ran the wrong sensor.** The core host step
  called `bin/omarchy-sense.sh` — the **Omarchy-only** sensor — so on any
  non-Omarchy host it learnt nothing and printed the sensor's own SKIP row as a
  host snapshot: `host snapshot:   sensor,SKIP,not an Omarchy host…`. On a Fedora
  workstation that is the whole discovery step, reporting a skip as fact.
- **Now it senses THIS machine with `bin/host-sense.sh`** — the portable sensor
  (the same one behind `ymir sense`) — on **every** host (Rule 05). Recording
  stays the Omarchy layer's job: `omarchy-sense observe`, the post-update hook,
  desktop placement, the plugin offer, and the alarm channel remain gated behind
  `step_omarchy`. Nothing here assumes Omarchy; nothing here skips the core
  machine either.
- `step_host` no longer branches on `--check`; it senses once and reports once:
  `host sensed: <os> / <id> / <family> / <session> / <desktop>`.
- The owning asset reflects it in the same change:
  `.agents/skills/galdr-ymirsystem/assets/installation.md` — the `host` step row,
  the Verify list, the two-layer table (recording, not learning), and the
  "Omarchy branches" note.
## 2026-09-16 — the visualizer finds its DB, and the seat-hall actually builds

Two more readers left behind — both discovered by *starting the apps*, not by any
gate. Each failed silently in its own way.

- **`scripts/start.sh` pointed the smithy at a repo path that no longer holds the
  DB.** `0003-private-data-separation` moved it to `$YMIR_HOME/smidja/smidja.db`,
  but the starter still passed `CMD_DB=<repo>/apps/smidja/smidja_data/smidja.db`
  — so the visualizer API died on boot with `smidja.db not found` and `:8437`
  answered nothing. It now resolves the same pair `bin/smidja-bootstrap.sh` does
  (home first, in-repo fallback, `SMIDJA_DB` override). The asset already
  *described* this resolution; the code now implements it.
- **`bin/sessrumnir-ensure.sh` never built the app.** `[ "$built_present" ]` tests
  a **literal, non-empty string** — always true — so `ensure --install` skipped
  `build_app` and reported `built: no` with exit 0. Sessrúmnir only built when the
  build was run by hand. Now `built_present` (the function) is called.
- `galdr-reread`: `.agents/skills/galdr-ymirsystem/assets/smidja.md` — the DB
  path, the `scripts/start.sh` DB resolution, and the observer's read list.

## 2026-09-16 — four readers that still pointed at the pre-split world

The app split and the hoard migration moved things; four readers never followed.
None failed loudly — each reported a clean PASS, a wrong SKIP, or a silent loss.

- **`bin/ymir-install.sh` wrote during `--check`.** The step chain ran
  `bin/ymir-migrate.sh apply` unconditionally, so a preview that promises *"report
  only, no writes"* actually **moved private data**. Migrations now apply only on
  a real run: `if [ "$CHECK" = 0 ]; then ... apply; fi`.
- **`.agents/migrations/0003-private-data-separation.sh` skipped every directory.**
  It pre-creates its target dirs, then its `copy` refused any target that already
  existed — so `data/` (and every other directory source) was silently dropped.
  The realm declaration never arrived and `0004` fell back to a neutral realm.
  `copy` now **merges** a directory into its target (never overwriting a file) and
  copies a single file only when it is absent.
- **`bin/smidja-bootstrap.sh` looked for the smithy at the old root.** `sys.path`
  pointed at `smidja/`, but the split moved it to `apps/smidja/`, so the DB seed
  died with `ModuleNotFoundError: No module named 'smidja_modules'`. It now
  searches `apps/smidja` then `smidja`, so either layout works.
- **`bin/ymir-validate.sh` read the ledger from the pre-move path.** It looked at
  `$YMIR_HOME/memory/`, but `0004-hoard-and-realms` put the ledger at
  `$YMIR_HOME/hodd/memory/` — a false `runes FAIL` on a healthy home. It now tries
  the hoard first, then the pre-move locations.
- `galdr-reread`: `.agents/skills/galdr-ymirsystem/assets/smidja.md` — the
  protected-paths gotcha and the `smidja/` → `apps/smidja/` move.

## 2026-09-16 — Omarchy-first, host-aware: Windows and macOS get a door

- **`bin/host-sense.sh`** — the one place that looks before anything acts. It
  reports THIS machine: distro and family, kernel, arch, platform (linux · wsl ·
  macos · windows), session (Wayland/X11), desktop, compositor, package manager,
  and what the desktop can actually *do* — `placement`, `launcher`, `tray`. No
  layer may assert a machine it is not standing on.
- **Omarchy stays first-class, and is now gated.** `bin/omarchy-sense.sh` opens
  by asserting *"Ymir runs on an Omarchy host"*; on any other host it now skips
  cleanly and points at `bin/host-sense.sh`, rather than recording the wrong
  machine. That is Rule 05's own rule: a layer is gated on its host.
- **Windows has a door:** `bin/bootstrap-windows.ps1` — enables WSL2, installs
  Ubuntu, then hands the work to `bin/ymir-install.sh` inside the distro. It is
  honest about needing elevation and about the one reboot a fresh machine needs.
- **macOS has a door:** `bin/bootstrap-macos.sh` — raises Ubuntu in a Lima VM and
  installs Ymir inside it, plus `packaging/macos/Ymir Installer.command`, a
  double-clickable launcher for an operator who should not need a terminal.
- **The installers themselves:** `packaging/build.sh --exe|--mac|--check`, the
  NSIS script `packaging/windows/ymir-setup.nsi` (→ `Ymir-Setup.exe`), and
  `.github/workflows/ymir-installers.yml`, which builds the exe on an Ubuntu
  runner (NSIS is a compiler, not a Windows VM) and the .pkg on a macOS runner
  (pkgbuild is Apple-only). Signing/notarisation stay with the operator, so the
  artefacts ship unsigned.
- `README.md` gains "Bringing your own machine" — the host table and the build
  commands; its `docs/masterplan.md` pointer is corrected to `$YMIR_HOME/docs/`.

## 2026-09-16 — app packaging prepared under the @ymir scope (Amendment C, part one)

- **Scoped names.** `apps/odrerir` was `ymir-odrerir` and `apps/sessrumnir` was
  bare `sessrumnir`; both are now `@ymir/odrerir` and `@ymir/sessrumnir`.
- **Publishable metadata on all four apps** (hlidskjalf, hlidskjalf-mobile,
  odrerir, sessrumnir): `license`, `repository`, `publishConfig.access: public`,
  a `files` surface, and `prepublishOnly` where a build exists.
- **Measured with `npm pack --dry-run --ignore-scripts`:** hlidskjalf 1.3 MB /
  21 files, odrerir 2.3 MB / 15, sessrumnir 4.0 MB / 116, hlidskjalf-mobile
  2.0 kB / 4 (source only — it has no build script). `dist/ymir.apk` is excluded
  by `!dist/*.apk`: it took the hlidskjalf tarball from 1.3 MB to 14.5 MB, and
  npm is not an APK channel.
- **`private: true` stays until the Allfather's word** — nothing can publish by
  accident; the flip is one line per app.
- The app repos were already registered in `$YMIR_HOME/identity/projects.yaml`
  (`zerwiz/{hlidskjalf,hlidskjalf-mobile,odrerir,sessrumnir,smidja}`).
- `no-mistakes` is initialized for this repo (`no-mistakes init`): the clean-PR
  gate now has its local remote. The vendored skill copy stays — it is the
  canonical tree the skill index names.

## 2026-09-16 — the loader stops deleting: merge, never overwrite

- **Root cause of the Apodex-provider loss, mended at the source.** Two writers
  share the untracked `opencode.json`: `bin/valknut-load.sh` (structure, from
  `opencode.json.example`) and `bin/agents-config.sh apply` (the roster —
  providers and per-agent models, from `config/agents.yaml`). The loader
  re-rendered with `sed` + `mv`, so because the example carried only
  `llama.cpp`, **every loader run silently deleted the Apodex provider** that
  lived only in the live file. `config_out` now merges deep and
  `setdefault`-style: missing keys are added, existing ones are never
  overwritten, and the skills path is ensured. Verified by wiping the provider
  by hand: the next run reports `merged(provider.apodex)` and restores it, while
  an unrelated hand-added key survives untouched. Seeding happens only when the
  file is absent.
- **The changelog guard still bites, without punishing a follow-up.** The
  pre-push guard now accepts either the pushed range touching `CHANGELOG.md` or
  the branch's whole range since it left the trunk touching it — a commit that
  merely lands a file the record already tells needs no micro-entry. A branch
  whose entire range leaves untold is still refused.
- `bin/valknut-load.sh --status` reports the config outcome
  (`seeded` · `merged(…)` · `unchanged` · `kept`), so a silent stomp can never
  hide behind a "rendered" line again.
- `harness-integration/README.md` records the two-writer boundary.

## 2026-09-16 — one skills tree, every harness; the config stomp mended

- **Every harness now reaches `.agents/skills`.** Pi was already right — its own
  code walks up from the cwd to `.agents/skills` (and `~/.agents/skills`), so it
  discovers Ymir's skills natively with no link and no config; a second root
  under `.pi/` would only double-load. Claude Code, Codex and Cursor read project
  skills from their own directory, so `bin/valknut-load.sh` now binds
  `.claude/skills`, `.codex/skills` and `.cursor/skills` to `../.agents/skills`.
  opencode reaches the tree through `skills.paths`. The install step `loaders`
  runs the loader, so a fresh install gets all of it.
- **The `harnesses` gate (G14) now asserts the skills surfaces too** — opencode's
  config, Pi's native root, and the three links — so a harness silently loading
  nothing can no longer pass.
- **Defect mended: the loader was stomping `opencode.json`.** `bin/valknut-load.sh`
  renders `opencode.json` from `opencode.json.example`, and that example carried
  only `llama.cpp` — so a loader run silently **deleted the Apodex provider**,
  which had only ever lived in the generated file. The example now carries Apodex
  as well, with the served id `apodex-1.0-mini`, so a re-render cannot drop it.
- `bin/valknut-load.sh --status` now reports every surface (agents *and* skills)
  with a true row count instead of a hardcoded header.
- Assets: `harness-integration/README.md` gains the skill-location table, and
  each per-harness file states its own mechanism.

## 2026-09-16 — Hodd lives outside the repo, and the installer makes it so

- **One resolver.** `bin/hoard-lib.sh` (`hoard_root`) is now the single answer to
  *where private data lives*: `$YMIR_HOARD`, else `$YMIR_HOME`, else
  `$HOME/Documents/Ymir` — never the checkout. Rule 07's one documented default,
  in one place.
- **The inward default is gone.** `bin/mimir-ingest.sh`, `bin/project-git.sh` and
  `bin/workspace-provision.sh` each fell back to `$ROOT/hodd`, so on a machine
  with neither `YMIR_HOARD` nor `YMIR_HOME` exported, memory ingest, the project
  registry and workspace provisioning wrote private data **inside the repo**.
  All three (plus `bin/hodd.sh` and the installer) now resolve through the lib.
- **The misplaced document is out.** `0003-private-data-separation.md`, which had
  come to rest in the repo at `hodd/docs/plans/`, now lives in the hoard at
  `$YMIR_HOME/docs/plans/`. The repo's `hodd/` holds exactly the guard, the
  README and `AGENTS.example.md` — Rule 04's scaffold set, and nothing else.
- **Installed, not assumed.** `bin/ymir-install.sh` step `tree` now raises the
  hoard layout *outside* the repo (`bin/hodd.sh init`) and seeds an empty
  `secrets/platform.env` (mode 0600), so `bin/hodd.sh emit secrets/platform.env`
  resolves on a fresh machine instead of failing with "not readable".
  `assets/installation.md` and `assets/memory-well.md` updated in the same change.

## 2026-09-16 — the pane bridge keeps its quoting; Phase 3 verified

- **The Apodex plan's last open verification is closed.** Run in a herdr pane —
  `bin/herdr-run.sh run huginn-research -- bin/huginn-research-worker.sh --brief
  "…" --output-dir …` — the worker recalled, dispatched to the Apodex seat, wrote
  its verdict, and observed it into Mimirsbrunn (`status: completed`, verdict
  *"The capital of Norway is Oslo."*). Phase 3 needed a spawn, which the
  read-only session lock had forbidden; it was run once the lock was this
  session's.
- **Defect found and mended — `bin/herdr-run.sh run` lost its quoting.** A pane
  runs its command through a *shell*, but the bridge handed herdr the raw argv.
  An argument containing spaces reached the pane as separate words, so
  `--brief "In one sentence: …"` arrived as `--brief In one sentence: …` and the
  worker died with `error: unknown arg: one`. Every real brief is multi-word, so
  the documented invocation could never have worked. `run` now quotes each
  argument on the way in (`printf '%q'`), verified by re-running it.
- Asset updated in the same change: `.agents/skills/ymir-host/assets/thjazi.md`
  carries the quoting rule.

## 2026-09-16 — the skill-loading audit: wrong skills unloaded, the index made true

- **Three phantom skills stopped loading.** opencode was loading `galdr-compliance`
  and `galdr-crafter` — both superseded, their work long since moved to
  `tyr-check` — and `NSR`, the NSR scaffolding spec, which sat at
  `assets/nsr/SKILL.md` carrying frontmatter. A recursive scanner walks
  `skills.paths` to *any* depth, so all three were announced to every agent as
  live skills. The two galdr crafters are removed; the NSR spec is renamed
  `assets/nsr/scaffold-spec.md` and stays a document (its sibling templates
  carry no frontmatter and were already inert).
- **Two gates added, one per failure class** (`compliance-check.sh`):
  - **`harnesses` (G14)** — every link in `.claude/agents`, `.codex/agents`,
    `.cursor/agents`, `.pi/agents`, `.opencode/agent` must land, one hop, in the
    canonical `.agents/agents/` tree (Rule 02), and no nested `SKILL.md` may
    carry frontmatter. One hop deliberately: Galdr's agent file *is* the skill,
    by the dual-surface rule.
  - **`skillindex` (G15)** — every real skill dir must be named in
    `.agents/skills/README.md`, and every `.agents/skills/<name>` path the assets
    cite must exist. Lines marked planned/legacy/superseded/removed/abandoned/
    retired are exempt by intent.
- **The drift they exposed, mended:** the canonical index listed 23 skills while
  26 existed (`groa-update`, `lifecycle`, `rules-check-drift` were missing); the
  Galdr and `.agents/assets/agents` registries still described a layout that no
  longer existed (`smidja/`, `gunnlod`, `hamr`, `saga`, `ymir`, `open-design`),
  pointing the agent at files that were not there; dead paths corrected to the
  real names (`smidja-factory`, `saga-bearings`, `urdh-hold`, `nornir-schedule`,
  `ymir-host`, `hamr-adapters`); `brokk-craft` marked planned rather than
  presented as a working command.
- **`AGENTS.md` gains the invariant:** the delivery gate is enforced in git
  hooks seated by the install step `gates` — `branch-guard` refuses a protected
  branch, `changelog-guard` refuses a push whose range never touches
  `CHANGELOG.md`.

## 2026-09-16 — the delivery gates install themselves; rename drift mended

- **Install seam.** `bin/ymir-install.sh` gains step **`gates`** (after
  `loaders`): `bin/secret-guard.sh --install` seats the pre-commit guard and
  `bin/changelog-guard.sh --install` the pre-push (branch + changelog). A fresh
  clone now gets the delivery gate without a manual step — `--check` reports it
  as `gates OK|WARN`, the consent preamble names it, and
  `assets/installation.md` carries the row in the same change.
- **Drift mended — found by the compliance gate, not by me.** Two symlinks
  still pointed at the retired `galdr-cli` skill, so the last rename was not in
  fact complete: `.agents/agents/galdr.md` (Galdr's agent surface was a **dead
  link**) and `.agents/skills/tyr-check/assets`. Both repointed at
  `galdr-ymirsystem`, which is where the skill and its assets live.
- **`AGENTS.md` TOON mend.** The `security[4]` block carried a rule wrapped
  across two lines, which the checker counted as a fifth row. Joined to one
  line; the block now declares and holds exactly four.
- **Compliance.** All ten Galdr gates green: toon · naming · mocks · syntax ·
  json · sync · surfaces · assets · duplicates · governed.

## 2026-09-16 — Smiðja moves into the app tree

- **The smithy is an app.** Its 148 source files moved from
  `.agents/skills/smidja-factory/` to `apps/smidja-factory/`, joining
  hlidskjalf, odrerir and sessrumnir under `apps/`.
- **Path-transparent.** `.agents/skills/smidja-factory` is now a symlink to
  `../../apps/smidja-factory`, so every existing path resolves unchanged —
  `scripts/start.sh`, `bin/ymir-install.sh`, `bin/ymir-validate.sh`, and the
  skill loader (`.agents/skills` is a skills path). `node_modules/` stays
  gitignored and is not carried.
- **Still open** (recorded, not done): the root `smidja/` runtime tree
  Amendment A would move to `apps/smidja/`, and Amendment C's per-app GitHub
  repos and npm publishing.

## 2026-09-16 — the changelog guard: no push ships untold

- **Every push carries a CHANGELOG entry.** `bin/changelog-guard.sh` installs a
  pre-push hook that reads the refs git hands it, resolves the range being
  pushed, and refuses the push when `CHANGELOG.md` is untouched in that range.
  A change that ships is a change that was told; the record can no longer lag
  silently behind the code.
- **Rule 08 extracted and versioned.** The protected-branch check that lived
  only inside the ad-hoc `.git/hooks/pre-push` is now `bin/branch-guard.sh`, so
  the delivery gate is reproducible: `bin/changelog-guard.sh --install` writes
  the pre-push that runs both guards.
- **Escape hatch, deliberate and loud.** `YMIR_SKIP_CHANGELOG_GUARD=1 git push`
  when an entry truly does not belong.
- Checks by hand: `bin/changelog-guard.sh --range A..B`,
  `bin/branch-guard.sh --branch main`.

## 2026-09-16 — Apodex seat verified; the Weave mended

- **Correction (cites the entry below, never rewrites it).** The earlier
  entry said *"LM Studio is retired; its :1234 port belongs to Apodex now."*
  That was false as carved. LM Studio still holds `:1234` and is what serves
  the Apodex GGUF; Apodex took the **model seat**, not the server.
- **Live verification.** `bin/apodex-smoke-test.sh` → PASS (valid tool-capable
  response, exit 0). `bin/huginn-research-worker.sh` with **bare defaults** →
  `status: completed`, verdict written, observed into Mimirsbrunn. The Apodex
  seat (`http://127.0.0.1:1234/v1`) is live.
- **One model id, everywhere.** The seat serves **`apodex-1.0-mini`**; the
  worker, smoke test, `.env.example`, `opencode.json`, `config/agents.yaml.example`
  and Huginn's profile now all say so. Previously three names drifted
  (`apodex/Apodex-1.0-mini-Q4_K_M`, `apodex/apodex-mini-q4`, the served id) and
  the default worker call failed with `No models loaded`.
- **Four defects mended.** `bin/huginn-research-worker.sh` made executable
  (was 644 — bare invocation died with `Permission denied`); the smoke test's
  `--serve` GGUF path corrected to
  `~/Models/FlameF0X/Apodex-1.0-mini-Q4_K_M-GGUF/apodex-1.0-mini-q4_k_m.gguf`;
  `bin/models-detect.sh` env var renamed from the typo `APEDEX_URL` to
  `APODEX_URL`.
- **Weight truth.** The Apodex Q4_K_M weights are **21.7 GB**, not the ~4–6 GB
  the plan assumed — it cannot sit beside a coding model. `AGENTS.md` now says
  so: one local model at a time, by weight.
- **Smiðja relocated.** `.agents/skills/smidja-factory` is now a symlink to the
  app tree at `apps/smidja-factory/`, which is where the smithy's real files
  live (Amendment A/C of the Apodex plan).
- Plan (private hoard): `$YMIR_HOME/docs/plans/apodex-integration-into-ymir.md`
  — Amendment E records the live pass, the mended defects, and the one open
  item: the herdr-seat verification (Phase 3), which needs a spawn.

## 2026-09-16 — Apodex joins the Weave (research/planning provider)

- **Apodex provider.** Apodex-1.0-mini-Q4_K_M climbs into the machine as
  the research/planning GGUF on `http://127.0.0.1:1234/v1`, seated
  alongside llama.cpp coding models on :8080. LM Studio is retired; its
  :1234 port belongs to Apodex now.
- **Env template.** `.env.example` gains the `APODEX_*` block; the LM
  Studio block is marked RETIRED with its port claim corrected.
- **Smoke test.** `bin/apodex-smoke-test.sh` — probe or serve-and-test an
  Apodex seat; exits 0=pass, 1=fail, 2=unavailable. Never mutates config.
- **Research worker.** `bin/huginn-research-worker.sh` (Apodex-powered
  Eindri): takes a brief, recalls from Mimirsbrunn, dispatches to the
  Apodex chat/completions seat, writes a structured verdict, observes it
  back into the well. Wears the name **Huginn** per the naming law (the
  research seat; Gungnir stays the skill-synthesis engine).
- **Agents hall.** `.agents/agents/huginn-researcher.md` binds Huginn to
  the apodex model; `config/agents.yaml.example` registers the apodex
  provider and Huginn's seat; `opencode.json` carries the apodex provider
  block alongside llama.cpp; `bin/models-detect.sh` probes and emits the
  apodex provider for the Pi model file (`~/.pi/agent/models.json`).
- **Install seams.** Apodex rides the existing seams: models-detect merges
  it into the Pi models file at install; agents-config applies it into
  opencode.json. Model provider selection documented in AGENTS.md
  (`## Model Provider Selection`), Apache 2.0 licence noted.

## 2026-09-16 — Gunnlöð joins the hall (SkillOpt integration)

- **SkillOpt integration.** `pip install skillopt` into `.venv/`; training
  loop (`skillopt-train`), eval (`skillopt-eval`), and nightly
  self-evolution (`skillopt-sleep`) available for Smíðja prompts and
  Ymir skills. Nightly Nornir job at 00:30 (bin/nornir-job-skillopt-sleep.sh),
  staged artifacts only — Allfather approves before adopt. One-time setup:
  `bin/skillopt-setup.sh`.
- **Naming.** SkillOpt adopted the name **Gunnlöð** (keeper of the mead of
  poetry — distills trajectories into refined skill artifacts). Added to
  `.agents/assets/agents/naming.md` (platform map, 28 subsystems),
  `.agents/skills/galdr-ymirsystem/assets/registry.md` (skills + external tools),
  `README.md` (System Map + Skills + gratitude), `NOTICE` (MIT attribution).

## 2026-09-13 — the imported names leave the halls (Norse naming purge)

- **"firstmate" retargeted to Ymir's own names across every Ymir-owned surface.**
  The upstream distro's nautical vocabulary is gone from the docs, skills, `bin/`,
  config, and the Hlidskjalf review copy: `firstmate` → **Brokk**, `secondmate` →
  **Eindri-home**, `crew`/`crewmate` → **Eindri**, `captain` → **Allfather**
  (`docs/lore.md`, `docs/Architecture.md`, `.agents/agents/brokk.md`,
  `.agents/skills/herdr-panes/assets/{herdr,tmux}-backend.md`,
  `.agents/skills/eindri-homes/assets/control-plane.md`,
  `.agents/skills/saga-bearings/assets/board-template.html`,
  `.agents/skills/ymir-host/assets/thjazi.md`, `bin/README.md`,
  `apps/hlidskjalf/**`).
- **Engine literals kept.** Every real upstream identifier stays verbatim — the
  Herdr labels (`firstmate`, `2ndmate-<id>`, `firstmate-<id>`), the home marker
  `.fm-secondmate-home`, the envelope `FIRSTMATE_OP: ` and `[fm-from-firstmate]`,
  and all `FM_*`/`fm-*` names — because `.agents/backend/` (the vendored engine)
  and `assets/reference/` (provenance) are untouched.
- **Licensing.** `NOTICE` now records the upstream **firstmate** distro
  (`github.com/kunchenguid/firstmate`, MIT, © kunchenguid) and a README "Built on"
  section points to it; the MIT copyright/permission notice is retained.
- **Governed asset:** `galdr-ymirsystem/assets/hlidskjalf-ui.md` records the Allfather
  review copy in the same change. `compliance-check.sh` 10/10 PASS.

## 2026-09-13 — The realm seat, carved (wayof)

- **Problem:** the realm tree was bare (only the shipped example), no tenant
  was seated, and the session digest resolved the Allfather's realm to
  `default` — his company and private holdings unreachable by the map.
- **Seat:** `svartalfaheim/wayof/` carved from the example — `.env.realm`,
  `SECRETS.md`, `AGENTS.md` (persona), `domains/`, `projects/`, the five
  workspace branches, and the 9 company cards seeded from the identity hoard
  (askr · brokkforge · dvalin · mannheim · muninn · runestone · utgard · wayof ·
  ymirlabs), realm field unified to `wayof`, repo paths corrected to this
  machine. `data/realm.md` now pins `wayof` (was drifting between `way-of`,
  `wayof`, and `default`; hoard cards + persona updated to match).
- **Hood:** `svartalfaheim/wayof/HOOD.md` is the map of the hoard and the
  seat; `bin/saga-session-start.sh` stage 6 (context digest) now prints
  `--- hood ---` whole from the realm seat, so a session opens knowing the
  operator's holdings. Living overviews: `workspace/company/wayof-overview.md`
  and `workspace/company/aigf.md` (hodd stays the private store; the realm
  points at it).
- **Verified:** `bash -n` green; realm-lib resolves `wayof`; `realm env:
  present`.

## 2026-09-13 — Gleipnir sees when an agent is turned off

- **Problem:** the machine lock stuck “held by another Brokk session” forever.
  Nothing released it ( `gleipnir_lock_release` had zero callers; Pi's exit
  hook only stopped the arm child), and liveness was `kill(0)` alone — which
  reports a zombie (dead but unreaped) and a recycled pid as alive, so an
  agent you turned off kept the helm until its pid happened to look gone.
  Worse, the Sessrúmnir desktop RPC session holds the live lock yet never
  arms supervision (no turn ever calls `gna_watch_arm`), stranding every
  other session read-only.
- **Fix:** `bin/gleipnir-lock-lib.sh` now records the owner's starttime in a
  `brokk.lock.starttime` sidecar and reaps a holder whose `/proc/<pid>/stat`
  state is `Z`/`X` or whose starttime no longer matches (pid reuse) — dead,
  zombie, and recycled holders are cleared at session start/acquire. Gná
  (`gna-pi-watch.ts`) mirrors that liveness, reclaims a stale lock directly in
  `gna_watch_arm` (`missing` no longer punts to saga-session-start.sh), and
  drops its own lock on real process exit (`releaseLockIfOwned`); the turn-end
  guard (`syn-turnend-guard.ts`) uses the same zombie-aware check.
- **Impact:** turning an agent off — cleanly, by kill (zombie), or after pid
  reuse — frees the machine lock for the next session. The live desktop seat
  still holds it until that app is closed or its own session arms; that is the
  law (one live primary per machine), but it now releases and hands off
  correctly.
## 2026-09-13 — the cloth reaches all three halls (Hlidskjalf · Smíðja · the seat)

- **One look, one source.** The carved cloth (the landing page's `:root`) now
  dresses every hall, each through its own thin adapter, and `docs/design.md`
  gained §0 *The cloth* plus the re-cut §4.1/§4.2 tables — the contract, not a
  wish. `midgard/design-system/tokens.css` keeps every `--ymir-*` **name** and
  changes only the values: stone `#0e0c09`/`#151209`/`#1a1610`/`#221d14`, bone
  text `#cfc3a9`/`#9a8f75`/`#6b6250`, bronze `#c9973f` accent with `#7d5f2a` as
  the brass rule, blood `#c2584a` danger, steel `#96a0a8` ok, brass bevel
  `inset 0 0 0 1px rgba(201,151,79,.12)`.
- **Type.** Cormorant (display), Newsreader (body), IBM Plex Mono (data) — the
  landing's three faces — with Noto Sans Runic appended to every stack so runes
  fall through to the rune family. Hlidskjalf loads them from Google Fonts; the
  visualizer bundles them from `@fontsource` (its `@fontsource/play` is gone).
- **Hlidskjalf:** 24 old-palette `rgba()` literals and every role hex in the
  stylesheets now read tokens (`color-mix(… var(--ymir-ok) …)`); workspace tints
  are cloth (work bronze, personal steel); the `HallsChooser` cards no longer name
  two tokens that never existed (`--ymir-line`/`--ymir-panel`); the login's GitHub
  button is a bone plate; the realm-tint fallbacks in `global.css` follow.
- **Smíðja's eye:** the default theme is **fensalir** (the titlebar toggle cycles
  fensalir → classic → high-contrast, both overrides still winning); 77 hexes and
  62 `rgba()`s across the components were recast onto the theme's own tokens; the
  categorical event/lane palettes (`src/lib/events.ts`) were re-cut onto the cloth
  while staying mutually distinct.
- **Sessrúmnir:** text selection is now a **theme token**
  (`--color-selection-bg`/`-fg`) — the landing's amber `#57411a` on pale bone
  `#f0e6cd` — carried in `fensalir`/`sessrumnir` and derived per theme for
  everyone else; the global rule sits in `@layer base`, and the CodeMirror editor
  needs a second unlayered rule because CodeMirror paints its selection layer with
  unlayered CSS that beats any layered rule. A **To the Hall** button joins the
  status bar (local `:4322` when it answers, else `hall.ymir.zerw.org`, resolved in
  the main process).
- **Heraldry is not chrome:** the eight house/domain seals and the Emblem keep
  their own colours — exactly as the landing page keeps its house seals.
- **Geometry is untouched** (radius, spacing, the shell): the carved-slate
  squaring remains an open question for the Allfather.
- **Verified:** `tsc` clean and `npm run build` green in Hlidskjalf; the
  visualizer builds under `vue-tsc`; Sessrúmnir's build, lint, theme tests and
  semantic-colour check green. Headless passes: Hlidskjalf's gates render with
  **0 console errors** (login, fleet, tasks, processes, reviews, runtime, cron,
  stats), and the visualizer loads with 0 console problems.

## 2026-09-13 — the carved cloth reaches the seat-hall (Sessrúmnir)

- **The landing's cloth is now the seat's own look.** Every semantic token in
  `apps/sessrumnir/src/renderer/src/index.css` `@theme` was mapped to its carved
  twin from the landing page's `:root` (`CodeP/ymir-homepage/src/lore.html`):
  stone `#0e0c09` (app) with panels `#151209`/`#1a1610`/`#14100b`, bone text
  `#cfc3a9`/`#9a8f75`/`#6b6250` (faint/ghost as bone washes), bronze
  `#c9973f` accent and `#7d5f2a` brass rule for `border-strong`, blood
  `#c2584a`/`#7c3a30` for error, steel `#96a0a8` for success. Semantic names are
  unchanged — only the values moved.
- **Fensalir** (the weaving halls) is registered as a built-in theme
  (`themes/fensalir.json`, id `fensalir`, appended to `BUILTIN_THEME_IDS` — an
  additive change that keeps every persisted id resolving). The seat's own
  built-in `sessrumnir` theme was carved to the same cloth, so the default look
  of an existing profile is the cloth on restart. A new test holds the two
  together (`the cloth is one`) and another holds the CSS `@theme` base to the
  theme file (`never drift`).
- **Cloth is the default, not a cage:** the ThemeEngine's ordering is untouched —
  every other built-in theme, any user theme, and `high-contrast` still win when
  chosen.
- **Type:** Cormorant (display), Newsreader (body), IBM Plex Mono (mono) bundled
  from `@fontsource*` (offline, `font-src 'self'`), with Inter/JetBrains Mono
  kept as glyph fallbacks; the landing's carved syntax palette (`--cm-*`) rides
  along in the theme files.
- **Honest repairs on the way:** 29 raw `text-white` literals sat on token
  fills where white cannot be read on bronze (2.6:1). They now read the token
  that means "the rune on the filled plate" — `text-inverse` on `bg-accent`,
  `text-primary` on the dark blood `bg-error` — and the settings toggle knob is
  carved (stone when lit, bone when unlit). No colour literals remain in
  components.
- **Paper:** `apps/sessrumnir/AGENTS.md` and `README.md` no longer claim the old
  sky-on-navy palette; they describe the cloth and its rules.

## 2026-09-13 — the new tree, the mesh, the seat-hall

- **Everything in the new tree:** the Sessrúmnir work plus the orphaned fixes
  were migrated from the `ymir-old` working tree into this canonical tree —
  `apps/sessrumnir/` (deps vendored locally, never committed), the two
  `bin/sessrumnir-*.sh` scripts, `step_sessrumnir` in `bin/ymir-install.sh`,
  the Hoard registry entry, the `installation.md` asset, and the
  `syn-watch-arm.js` continuity fix (re-arm when `.supervision-armed` exists
  even with no task metadata). The superseded self-service register-gate work
  was **not** ported — this tree's committed invite-gate is canonical.
- **Full install ran green** in the new tree: every step OK, invite minted
  (`YMIR-DBN4-FXEX`), all five services up, `bin/ymir-validate.sh` 11/11 PASS.
- **Ratatoskr mesh healed:** the `a2abridge` engine (MIT,
  `vbcherepanov/a2abridge` v3.0.0) is installed at `~/.a2abridge/bin/`, its
  directory daemon runs on `127.0.0.1:7777`, and `bin/ratatoskr.sh
  status|doctor` pass. Forged `bin/a2abridge-ensure.sh` (installs the engine,
  patches the systemd unit's unwritable `/var/log` log paths to journal,
  keeps the directory up) and wired it into migration `0002-a2a-mcp.sh`, so
  every install/update heals the mesh instead of leaving a dangling MCP path.
- **MCP bridges fixed:** `engram-mcp` failed at startup (its Python env
  lacked the `mcp` SDK; mcp 2.x renamed FastMCP, so it is pinned to `mcp<2`)
  — the server now initializes against the `kaia.engram` store. `a2abridge`
  MCP is wired into both pi and opencode via `bin/a2a-mcp.sh install`.
- **Docs:** `docs/design.md` §5.4 documents the gate exactly as committed
  (operator credential + invite-gated registration + GitHub door + httpOnly
  30-day session); the hlidskjalf-ui skill gained the `register` surface row.

## 2026-09-13 — Sessrúmnir, the seat-hall

- **Sessrúmnir adopted:** the Apache-2.0 **pi-desktop** GUI
  (`FaqFirebase/pi-desktop`, v0.1.7-alpha) is vendored at `apps/sessrumnir/`
  and rebranded **Sessrúmnir** — the seat-hall where the Allfather converses
  with the machine. The external engine keeps its product name; the GUI the
  user sees is Sessrúmnir, themed with the way-of palette (sky `#38bdf8` on
  deep navy) as the new default built-in theme. Window titles, launcher,
  package identity, tray/autostart strings, data-dir name, and the Pi logo
  (now a Sowilo rune bolt) are rebranded; upstream `LICENSE` is preserved and
  `NOTICE` records the adoption.
- **Forge scripts:** `bin/sessrumnir-ensure.sh` (status/ensure/install — deps
  are never committed, installed on first run with the electron-binary heal
  `scripts/electron.sh` already uses) and `bin/sessrumnir.sh`
  (start/status/stop with a workspace argument).
- **Install wiring:** `bin/ymir-install.sh` gains a `sessrumnir` step (after
  `hermes`) and lists Sessrúmnir in `workspace/INSTALL.md`; the
  `installation.md` asset's step table, adopted-engines table, and Hermes-style
  section are updated in the same change.
- **Registry & audit:** the Hoard registry (`hodd/identity/projects.yaml`)
  gains the `sessrumnir` project (upstream remote); the adoption is inscribed
  in Runes.
- **Not yet installed:** `apps/sessrumnir/node_modules` is absent — run
  `bin/sessrumnir-ensure.sh install` when ready.

### 2026-09-13 — the seat-hall raised

- `bin/sessrumnir-ensure.sh install` completed: deps + Electron binary + build
  all green; full test suite **989/989 pass**, typecheck and lint clean (the
  `autostart-linux` test was updated for the new brand name). `bin/sessrumnir.sh
  start` raised the window — Hyprland reports class `sessrumnir`, title
  `Sessrúmnir`, data under `~/.config/sessrumnir`.

## 2026-09-12 — The well actually installs (it never did)

- **The memory engine was never installed by the installer.** `bin/prereq-ensure.sh`
  had no `engram` target at all, and `bin/ymir-install.sh` only *checked* for it
  and printed `SKIP "optional — install engine then run bin/mimir-bridge.sh"`. A
  SKIP never blocks, so the well was silently down on every install.
- **The hint named the wrong package.** PyPI's `engram` is an unrelated
  *rendering* library (mitsuba/drjit/torch): following the hint pulled gigabytes
  of CUDA wheels and still left no engine. The memory engine's distribution is
  **`engdbram`**; its module is `engram`. The pre-swap append-only log had the
  right answer all along (`PyPI engdbram, v2.2.1`).
- **Now it installs.** `prereq-ensure.sh engram` installs `engdbram` into an
  interpreter that can run it (>=3.11; uv supplies 3.12 here), records that
  interpreter in `~/.config/ymir/engram-python`, and `bin/mimir-bridge.sh` reuses
  it for both the check and the run. The installer provisions rather than hints,
  and reports WARN instead of a silent SKIP when it cannot.
- **Verified:** `curl 127.0.0.1:4602/health` -> `{"status": "up", "store":
  ".agents/memory/kaia.engram"}`; `.agents/skills/lifecycle/smoke_test.sh` exits 0
  with all five checks green.

## 2026-09-12 — The dashboards stop crash-looping on the iGPU

- **`scripts/electron.sh` decides its own GPU path.** Both dashboards appeared to
  work while `coredumpctl` filled with SIGSEGV cores from
  `electron --type=gpu-process`. An iGPU backs its graphics memory with system
  RAM (GTT), a local model served on that same iGPU held 5.8-8.0 GiB of it, and
  the amdgpu driver then failed the desktop's command submissions — which
  Electron turned into a NULL dereference at a constant offset. Only the GPU
  process died, so the windows stayed up and the failure was easy to miss.
  `igpu_vram_small()` now reads the render device's VRAM carve-out and switches
  to software rendering under `YMIR_IGPU_VRAM_SMALL_MIB` (default 2048). The old
  comment promised this auto-detect; now it exists. `YMIR_DESKTOP_DISABLE_GPU`
  still overrides, both ways.
- **Verified:** with the fix, the amdgpu submission errors stop and the
  gpu-process runs SwiftShader (`--use-angle=swiftshader-webgl`) rather than the
  hardware path; no new cores.

## 2026-09-12 — The editor keeps its own seat

- **`open-editor.ts` seats the editor in Þjazi:** inside herdr, `/edit` and
  `ctrl+shift+e` now open the Allfather's editor in its **own tab** of the home
  workspace (`herdr tab create --focus` + `herdr pane run`, label
  `ymir:edit[:<base>]`, recorded in `state/herdr-seats` for `close-all`) instead
  of suspending the pi session — the agent no longer dies when the editor
  opens. Outside herdr the old roads remain: GUI editors launch detached,
  terminal editors suspend the TUI and resume on exit.
- **`open-editor.ts` shows hidden files:** the picker and `/edit`
  tab-completion now merge the git listing with a bounded walk, so gitignored
  dotfiles (`.env.local`, `.env.realm`, …) are openable too.

## 2026-09-11 — Omarchy-first: host skills, machine learning, native fixes

- **New skill `ymir-omarchy`:** Omarchy-native operation — the two laws (never
  edit `/usr/share/omarchy/`; Hyprland owns placement), host detection, the
  monitor/scale coordinate trap, the amdgpu GPU crash and mitigation, desktop-app
  placement, and a safe-customisation table.
- **New skill `ymir-thjazi`:** Þjazi (herdr-first) — protocol floors (14+ panes,
  0.8.0 presentation spaces), verification, installation.
- **Ymir learns the host:** `bin/omarchy-sense.sh` snapshots and *diffs* the
  machine (Omarchy version, explicit packages, config files, monitors, scale) into
  `state/omarchy-setup.json`; `bin/omarchy-hook-install.sh` adds an Omarchy
  `post-update` hook so it re-learns after every `omarchy update`.
- **Þjazi in the installer:** `bin/herdr-ensure.sh` + new `step_backend`
  (herdr, else tmux — never a silent fallback).
- **New `step_omarchy`** (SKIP on a non-Omarchy host).
- **Desktop fixes:** window placement is now LOGICAL and work-area clamped, and
  prefers a non-primary display (the old math used physical pixels on a scale-1.5
  panel and filled the screen). Apps are identified by their command line, not the
  `.bin/electron` shim pid — which fixes the **double-launch** bug. `stop` kills
  every matching pid.
- **GPU mitigation:** `YMIR_DESKTOP_DISABLE_GPU=1` adds
  `--disable-gpu --disable-gpu-compositing` for small-VRAM iGPUs (the crash was
  `amdgpu: Not enough memory for command submission`, SIGSEGV, not an OOM).
- **Per-machine state un-shared:** `.agents/memory/kaia.engram*` and
  `well/*.jsonl` were tracked and pushed (one machine's private memory + volatile
  SQLite sidecars). Now gitignored and untracked; the contract is written in
  `.agents/memory/README.md`.
- **Assets updated:** `installation.md` (15 rows, consent, validation, Omarchy),
  `hlidskjalf-ui.md` (the desktop-apps section).
- **Verified:** full install green (15 rows; only the docker-group WARN), 9/9
  compliance, both skills registered.

## 2026-09-11 — Load the owning asset before editing a governed path (5 layers)

The runtime drifted from its documentation because the asset that governs a
subsystem was never loaded before the code changed. Five layers now prevent it:

- **1. `AGENTS.md`:** a new `governed[6]` table maps each governed path to the
  asset to load first, and `manual[]` gained `installation`, `ui`, `runtime-spec`.
- **2. Session digest:** `saga-session-start.sh` prints an `ASSET ROUTING` block
  every session, so the mapping is always in context.
- **3. Router loadable:** `galdr`'s `disable-model-invocation` is removed (it hid
  the one router that owns the assets); `tyr-check` keeps it (deliberate).
- **4. Enforced seatbelt:** new `bin/syn-asset-pretool-check.sh` denies an
  `edit`/`write` of a governed path until its asset was read (`state/asset-reads`);
  the Pi extension relays it and records asset reads.
- **5. Compliance gate:** `compliance-check.sh` gains an `assets` check that
  FAILS when a governed path changed without its asset (it caught this very
  change), and `runtime-compliance.md` documents G12 + the routing map.

## 2026-09-11 — Automate the install: consent gate, self-healing prereqs, visualizer-ready

- **Consent gate:** a real install now prints its plan and waits for the operator
  to accept (`[y/N]`). Declining changes nothing (exit 3). `--check` still previews
  without asking; non-interactive callers must pass `--yes`.
- **New `bin/prereq-ensure.sh`:** self-healing prerequisites in USER SPACE —
  installs `bun` and `uv` via their official installers, `mcp<2>` via pip, and can
  fetch a specific Python (e.g. `3.12`) with uv for packages that need one.
- **New `bin/smidja-bootstrap.sh`:** creates `smidja/smidja_data/smidja.db` from
  the tracer's own schema and seeds a bootstrap session, so the Smíðja visualizer
  has data from the first install. Fixed: it now bootstraps on a bare call
  instead of printing help, and reports failure honestly when the DB is absent.
- **`bin/ymir-install.sh`:** new `smidja` step; prerequisites delegated to the
  self-healing helper; `engram` reported as an honest optional `SKIP` with the
  exact next command; docker-group-permission and build-failure distinguished.
- **Verified:** consent refuse/accept/decline paths; smidja db created and read
  back (8 tables, bootstrap session); compliance 8/8.

## 2026-09-11 — Smooth install: provider choice, no forced key, real prereqs

- **Model provider is now the operator's choice** (`YMIR_MODEL_PROVIDER`):
  `opencode-go` (needs a key), `lmstudio` (keyless local), or
  `openai-compatible`. The bridge no longer forces `OPENCODE_GO_API_KEY`;
  with no key it auto-selects the keyless local provider so a fresh install works.
- **New:** `.agents/backend/model-bridge.py` (provider-aware, keyless-capable);
  `opencode-go-bridge.py` kept as a delegating shim so existing references work.
- **`bin/bifrost-bridge.sh` v2:** `--provider`, provider auto-selection, no hard
  env-file requirement, actionable errors per provider.
- **`bin/ymir-install.sh`:** installs `bun` for real (user-space, then a package
  hint); installs `mcp<2`; `engram` is now an honest `SKIP` with the Python
  version reason instead of a permanent WARN; distinguishes docker-group
  permission from a build failure.
- **`scripts/start.sh`:** fixed the early exit that skipped the gate API and all
  services whenever the SPA was already running.
- **Verified:** compliance 8/8; bridge relays models + chat + 404s; keyless
  start confirmed; `start.sh` raises Gate API, Nornir, Bifrost, visualizer.

## 2026-09-11 — Single-tenant workspaces shipped

- **First setup:** `bin/ymir-install.sh` (8 steps) + `bin/workspace-provision.sh`.
- **Model:** single tenant; workspaces (personal|work) over domains; houses = brands.
- **UI:** Login onboarding (name/kind/domains), Topbar workspace chip, AccountMenu/Profile relabelled.
- **Engines:** treehouse → `yggdrasil.sh pool`; sandcastle → `utgard.sh sandcastle`; no-mistakes → Mjollnir gate.
- **GitHub:** `bin/project-git.sh` reads `workspace/projects.yaml` `git{}`.
- **Verified:** build green, compliance 8/8, smoke 8/8, lint 4/4.

All significant runtime, policy, and architectural changes for the Ymir platform.
Entries are appended chronologically; never rewritten.

## 2026-09-11 — Hardcoded per-page feeds (header + stream)

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

## 2026-09-11 — Per-page rolling 40 message feeds

- **Change:** the bottom stream is no longer one global 120-line feed. Every gate
  keeps its own rolling window of the **last 40** messages, and events are routed
  to the page they belong to (module → gate: `well`, `sessions`, `forge`,
  `runes`, `cron`, `reviews`, `processes`), with the fleet-wide feed as fallback.
  The stream header shows the current page. `STREAM_WINDOW = 40`, matching the
  chat's `CHAT_WINDOW = 40`.
- **Verified:** `tsc` + `vite build` green, SPA 200.

## 2026-09-11 — Galdr/Tyr assets: symlink, not copies

- **Fix:** `tyr-check/assets` is now a **symlink** to the canonical
  `galdr/assets`, so the two can never drift. A background process had been
  rewriting the registry, flipping the sync gate red; a symlink makes drift
  structurally impossible. Compliance back to 8/8 stable.
- **Verified:** compliance 8/8, smoke 8/8, lint 4/4.

## 2026-09-11 — Chat uses the root Pi model catalog

- **Fix:** the Kaia chat guessed a llama.cpp model id by regex and fell through
  to the Bifrost bridge (`:4603` → 401) when the guess failed.
- **Now:** the gate API reads the operator's root Pi catalog
  (`~/.pi/agent/models.json`) for the exact provider → base URL, model id, and
  key (llama.cpp router `:8080`, `sk-not-key-required`). A chosen local model
  is tried only on its own base; the default is the operator's Pi default
  (`qwen3.6-35b-a3b@iq3_s`). `/api/chat/models` lists the real connected set.
- **Verified:** `gemma-4-12b@q3_k_s`, `qwen3.6-35b-a3b@iq3_s` (default), and
  `qwen3.5-9b@q4_k_s` all answered live; no 401.

## 2026-09-11 — Shared well for every harness; no mock; clickable memories

- **Harnesses:** the engram MCP server is now registered for all four OpenCode
  accounts (`opencode`, `opencode-rd`, `opencode-work`, `opencode-oczer`), Pi
  (`~/.pi/agent/settings.json` + `mcp.json` + `.pi/mcp.json`), Claude, Cursor,
  and Codex. Registered **unscoped** so every harness reads the one shared well
  (per-call `agent_id` still attributes writes).
- **No mock:** purged every test/mock episode (`smoke`/`Test observation`) from
  both the engram store and `episodes.jsonl` → 367 true episodes. Test writes
  never enter the well.
- **UI:** Well memories are now **clickable** — `GET /api/well/episode?id=` and
  a bridge `/episode` endpoint feed a modal with the full memory text.
- **Bridge fix:** `/recent` and `/recall` restored; added `/episode`.
- **Lifecycle fix:** `bifrost-bridge.sh` / `mimir-bridge.sh` now stop by process
  match when the PID file is missing, and record the PID when the port is
  already up — so `scripts/stop.sh` truly lowers the whole system and
  `scripts/start.sh` truly raises it.
- **Galdr:** new asset `.agents/skills/galdr-ymirsystem/assets/memory-well.md` (store,
  bridge, MCP, harness matrix, laws, verify), routed in `SKILL.md`; registry +
  harness README updated; mirrored to tyr.
- **Verified:** MCP recall 1.0 / stats 367, full stop→start cycle (3888/3889/
  4602/4603/8437), compliance 8/8, smoke 8/8.

## 2026-09-11 — The well is real (Mimirsbrunn / engram)

- **New:** `bin/mimir-bridge.py` + `bin/mimir-bridge.sh` — the `:4602` HTTP face
  the supervision tree named but that upstream never shipped (engram exposes a
  CLI + MCP server only). Endpoints: `/health`, `/recall`, `/recent`,
  `/timeline`, `/inspect`, `/observe`.
- **New:** repo-local store `.agents/memory/kaia.engram`, seeded from the
  368-episode JSONL well.
- **Wired:** gate API `/api/well` now does semantic recall via the bridge (local
  file fallback) and `/api/mimir/health` is live; the Well gate's Bridge tile
  and timeline read real data (mock removed).
- **Harnesses:** the engram MCP server is registered for OpenCode, Pi, Claude,
  Cursor, and Codex; requires the `mcp<2` SDK (`engram-mcp` breaks on mcp 2.x).
- **Lifecycle:** the bridge is raised by `scripts/start.sh` and
  `bin/saga-session-start.sh`; the stale `engram.server` command was corrected.
- **Verified:** bridge up (370 episodes), semantic recall, MCP handshake
  (engram 1.30), compliance 8/8, smoke 8/8.

## 2026-09-11 — Stats 1:1, Kaia chat, Forge prompts

- **Stats:** ported the full Smiðja `StatsResponse` 1:1 into the gate API and
  the Stats gate — runs/success/fail/running/rate, token optimization
  (input/output/cache_read/cache_write, cache-hit ratio, avg CHR/run),
  local-vs-online provider split with per-model table, 40-model commercial
  catalog (cached/total/savings/%), by-chain and by-workflow. A real run
  renders live.
- **Chat (Kaia):** per-session JSONL store (`state/chat/`), list/history/delete
  endpoints, a rolling **40-message** window, query-grounded well recall before
  every dispatch, an animated "Kaia is thinking…" indicator, a session sidebar
  (new/switch/delete), a connected-model datalist (314 models) with free-type,
  and Eindri lane toggles.
- **Forge:** a Prompts mode to read/edit the smithy's
  `prompt_engineering/<agent>/{system,user}.md` (path-guarded save) and a
  connected-model datalist for agent models.
- **Verified:** `tsc` + `vite build` green, live chat via local model with
  recall on, prompt roundtrip + traversal guard, compliance 8/8, smoke 8/8,
  lint 4/4.

## 2026-09-11 — Smiðja views are repo-local

- **Change:** Removed the last external dependency. `bin/factory-observe.sh`
  (which defaulted to `~/command/factory/factory_data/factory.db`) is gone;
  `bin/smidja-observe.sh` reads the repo's own
  `smidja/smidja_data/smidja.db` read-only and reports absence honestly.
- **API:** `/api/factory` replaced by `/api/smidja/{health,sessions,sessions/:id,decisions,stats}`
  (`bun:sqlite`, read-only).
- **UI:** four Hlidskjalf gates added — Sessions, Trace, Decisions, Stats —
  reading the smithy's trace. No `command`/`factory` references remain in the
  runtime or portal.
- **Verified:** `tsc` + `vite build` green, SPA 200, endpoints honest-absent,
  Galdr compliance 8/8, smoke 8/8.

## 2026-09-11 — Gleipnir lock PID binding fix

- **Problem:** The session lock (`state/.lock`) was written with the digest
  helper's PID (a short-lived child) instead of the live Pi harness PID. The
  harness adapter (`gna-pi-watch.ts`) reported "no live session holds the lock"
  and refused to arm the watcher.
- **Root cause:** `BROKK_SESSION_PID` was never injected into the spawn chain.
  `gleipnir_lock_acquire` fell back to `$$` (helper PID).
- **Fix:** `.pi/extensions/syn-turnend-guard.ts` and
  `.pi/extensions/gna-pi-watch.ts` now pass `BROKK_SESSION_PID: String(process.pid)`
  in the spawn env, so the lock binds to the live Pi process.
- **Impact:** Session lock reclamation works on next Pi session start/reload.
  The stale lock (dead PID) is overwritten by the live PID.

## 2026-09-11 — Desktop shell, tunnel, and temporary auth

- **Electron:** `apps/hlidskjalf/electron` + `scripts/electron.sh` open Hlidskjalf
  (and Smiðja) as a native window; raises the stack if down.
- **Tunnel:** `ymirdell.zerwiz.org` → `:3889` via `bin/gjallarhorn-tunnel.sh`
  (cloudflared config in `midgard/infrastructure/ingress/cloudflared-ymir.yml`).
- **Auth:** hardcoded HTTP Basic (`zerwiz:allfather`, `HLIDSKJALF_AUTH`) on the
  gate API, which now also serves the built SPA. Temporary — move to Heimdall +
  `.env.local`.
- **Mobile:** PWA manifest added; recommended APK = Capacitor over the tunnel.

## 2026-09-12 — Updater forged + credential moved to env

- **`bin/brokk-update.sh`** — the sanctioned, guarded updater the `ymir-update`
  skill calls: fast-forward only, refuses a dirty/diverged tree, `--yes` to
  stash+restore, `--check` to report. Never force-pushes.
- **Credential law:** the gate login (`HLIDSKJALF_AUTH`) no longer has an inline
  default; it is read from `.env.local` (Bun auto-loads it). Server falls back to
  an open gate only when unset (dev), with the key added to `.env.example`.

## 2026-09-12 — Ró preference moved out of the tracked tree

- `.agents/config/ro` was a **git-tracked** per-user toggle (calm on/off); any
  toggle dirtied the tree and made `bin/brokk-update.sh` refuse. It now lives in
  the gitignored `state/ro`; `YMIR_RO`/`BROKK_RO` set a default; the legacy
  `config/ro` is read once for upgrade then never written. Tracked file removed.

## 2026-09-12 — Fleet preferences

- `data/fleet.md` (gitignored) holds fleet-wide per-user settings (`ro: on|off`).
- `bin/fleet-apply.sh` applies them to this home + every registered Eindri-home
  (into each home's gitignored `state/`; remote routes reported).
- `bin/brokk-update.sh` re-applies fleet preferences on every sweep — one setting
  reaches the whole fleet, no tracked tree dirtied.

## 2026-09-12 — House law (RULES/) and the Grein naming

- New `RULES/` (the house law): `01-domains.md` (house = company; domain = a
  **Grein**/**Greinar**; Eindri = specialists), `02-agents.md` (agents live only
  in `.agents/agents`; harness dirs are symlinks; no mock agents), `03-houses.md`
  (a house is a company — WayOf; the eight Labs are domains, never houses).
- Live Fleet de-mocked (real domain/model/status; seeded stats only in demo).

## 2026-09-14 — A vacant helm is entered, not punted (watcher wake repair)

- **Problem:** a watcher wake reported the Pi extension could not restore
  continuity — "this session no longer owns the lock". Root cause found by
  inspection: an **empty/truncated** machine lock (`~/.local/state/ymir/brokk.lock`)
  was classified by `gna-pi-watch.ts` `lockOwnership()` as `other` (another
  live session) and by `bin/syn-watch-arm.sh`'s gate as read-only — so a helm
  with *no verifiably-live holder* was refused and punted to a manual
  `saga-session-start.sh` reclaim.
- **Fix (both seams in one change):** the extension now classifies an empty
  lock as `missing`, so `gna_watch_arm`'s reclaim takes the helm in place; the
  arm script, on finding no owner (or an owner verifiably gone), runs
  `gleipnir_lock_acquire` itself — which refuses only a genuinely live other
  session — instead of printing read-only. The "run saga-session-start.sh"
  punt is gone; a vacant helm is entered by the watcher's own hand.
- **Verified:** scratch-state test — empty machine lock → `watcher: started`,
  lock bound to the session pid + starttime sidecar, `.supervision-armed`
  touched; `gleipnir-machine-lock.test.sh` ALL PASS (zombie, recycled,
  migration); compliance 10/10; harness-integration asset updated in the same
  change (the governed rule).

## 2026-09-14 — The Eindri→Brokk wake bridge (they can talk back now)

- **Ask:** the seated smiths' reports lived in their panes only; the Allfather
  wanted a feature that wakes Brokk when an Eindri reports, so the fleet's
  doings reach the primary's session — "we are in control, Brokk".
- **Built:** `bin/eindri-seen.sh` (condition — a report file landed or herdr
  shows the smith left `working`), `bin/eindri-acclaim.sh` (action — files the
  report durably under state/eindri-reports/, marks done under
  state/eindri-done/, appends the wake to state/.wake-queue for Sága's drain,
  sounds the desktop note), and `bin/eindri-watch.sh` (the control door —
  `arm | retire | list | reconcile`, one when-source per smith on the Norns'
  loom via fm-procevent-when.sh, action hash-bound, fires once on a stable
  true, terminal, re-armable).
- **Armed live:** when-odrerir (already fired — his report was filed) and
  when-sessrumnir-cloth (still working). `fm-procement.sh reconcile` started=2.
- **First report delivered through the wire:** odrerir's Óðrerir saga — deck
  green at :4322, 52 Chromium checks, commit 38a326b on yggdrasil/odrerir, main
  untouched, plus the hall.ymir.zerwiz.org server story (setup-hall.sh) and
  three asks awaiting the Allfather (go live, landing mobile wart, PLAN log).

## 2026-09-14 — Óðrerir forged (Eindri odrerir, pane w3:p7)

- The Live Hall carved on the landing per PLAN.md §14: dealt slate pile,
  choices + recommended marks, freeform, queue + limit guard, thread ledger,
  live tally, four empty states, fail-closed, keyboard, reveal, mobile (390px,
  zero overflow); cloth check green; §12 scan clean. Deployed plan for the
  public hall: hall.ymir.zerwiz.org via a second Caddy site :4322 (deploy/
  setup-hall.sh + tunnel-ingress.sh, idempotent, live provisioning untested).

## 2026-09-14 — The echo guard: no wake flood through Gná's door

- **Problem:** during a loud stretch (stale wake lines + the FM runner's
  durable queue holding ten old check-wakes), the watcher re-armed and
  re-signalled "signal: wake queue" across many generations; every actionable
  close queued one pi follow-up wake (`sendWake`, no dedup), which then
  dripped at the Allfather one per prompt — a long echo flood after the
  sources were drained.
- **Fix:** `gna-pi-watch.ts` `sendWake` is **echo-guarded**: an identical
  watcher message is delivered at most once per drained state — when both
  durable doors (`state/.wake-queue` and the FM runner's
  `.agents/state/.wake-queue`) are empty, a repeat carry is the same drained
  news and is skipped. Genuine new content (different message, or a door with
  a line) always delivers. Harness asset updated in the same change.

## 2026-09-16 — one login for every app on the web; the gate fronts them all

- **Every app host is gated**, not just Smíðja. The gate now routes by host from
  an `APP_HOSTS` table and fronts each one: unauthenticated visitors get that
  app's own sign-in page, an API path gets 401, and the desktop seat (loopback +
  marker) walks straight in. Verified: `smidjadell…` → *Smíðja — Sign in*,
  `odrerirdell…` → *Óðrerir — Sign in*, API 401, desktop seat 200 (the hall).
- **Every public hostname points at the gate (:3889)** — never at an app's own
  port. That was a hole straight past the login: `gjallarhorn-expose.sh` had been
  exposing each app on its own port, so the app answered the world directly.
- **The gate learns the host map at start** (`state/gjallarhorn-hosts.env`,
  written by the expose script and sourced by `scripts/start.sh`), so routing is
  not an accident of whoever launched it last.
- **No guessed credentials.** The generated tunnel config wrote
  `credentials-file: …/ymir.json`; cloudflared names that file for the tunnel's
  UUID, so it refused to start and the world got 530. The line is gone —
  cloudflared resolves a named tunnel's own credentials.
- Verified through the tunnel: `https://ymirdell.zerwiz.org/` → 200. The app
  hostnames still answer 530: their DNS routes were made against an earlier
  tunnel and need re-creating (`cloudflared tunnel route dns ymir <host>`).

## 2026-09-16 — NO BLUE: the forge language replaces the old blue

The blue had a name. It was the platform's own house tint, `--ymir-house-ymirlabs:
#38bdf8`, carried into every surface that wears Ymir's colours — the login, the
emblem, the realm data, the Smíðja chrome. The design doctrine (homepage repo,
`DESIGN-UNIFICATION-PLAN.md`) says the landing page **is** the language, and that
language is **forge**: stone ground (`#0e0c09`), bronze accent (`#c9973f`), bone
text (`#cfc3a9`).

- `midgard/design-system/tokens.css` — the house tint is bronze now, with the
  reason recorded in the token itself.
- The blue's footprints removed: `Emblem.tsx`, `state/store.ts`, `data/realms.ts`
  (Hlidskjalf), `style.css` (Smíðja visualizer), and Sessrúmnir's terminal accent
  fallback.
- Both built stylesheets rebuilt and verified: **zero blue** in the CSS the browser
  actually receives (`apps/hlidskjalf/dist`, the visualizer's `dist`).
- The visualizer's build was failing on my own earlier edit (unused imports left
  when I moved `repoRootOf` into `db.ts`) — fixed, so `bun run build` is green.

The canonical token home is answered by what already exists: `midgard/design-system/`
(tokens, icons, `ymir-mark.svg`, `icons.md`) — one source the apps import, so a
colour changes once.

## 2026-09-16 — every app wears its own rune

The icon set is runecoded (`midgard/design-system/icons.md`): an Elder Futhark
rune, stroked at the chisel bevel, tinted by the app's house colour. The apps were
wearing the generic Ymir mark — or, worse, the old **blue** logo.

- **`bin/design-icon.sh`** mints an app's icon from a glyph plus a house tint: a
  stone tile with the rune stroked in bronze. `list` shows the mapping.
- Minted and wired: **Hlidskjalf** `ehwaz` ᛖ (the seat), **Óðrerir** `valhalla` ᚹ
  (the hall), **Sessrúmnir** `sowilo` ᛊ (the sun), **Smíðja** `ansuz` ᚨ (Odin's
  breath — the forge). Óðrerir already carried a forge-coloured favicon set.
- **The blue logo is retired**: `public/logo.svg` removed, and Smíðja's *inline*
  copy in `App.vue` — the mark in its own header, still `#0f172a`/`#1e293b` —
  replaced with the ansuz rune in bronze. Rebuilt; no blue in the bundle.

### The hearth stays, and spreads

Sessrúmnir's background fire is **`EmberBackground`** — 26 embers rising with a
gentle sway on a canvas, *"the hearth of the landing page, carried into the
chat"* — used by its home screen and chat panel. It stays. Next: one shared
ember (a framework-neutral `midgard/design-system/ember.js` with a
`prefers-reduced-motion` guard) so Hlidskjalf's shell, the login screen,
Óðrerir's hall and the Smíðja chrome can warm the same fire.

## 2026-09-16 — the hearth spreads: one fire, three more surfaces

Sessrúmnir's fire is now shared rather than copied. `midgard/design-system/ember.js`
is the framework-neutral original (the land page's Ginnungagap embers: 30 rising
with a gentle sway over six drifting haze pools), with `ember.d.ts` for TypeScript
consumers and a reader who asked for less motion gets a **still frame** instead of
an animation.

Wired, and built:

- **Hlidskjalf** — `src/components/EmberBackground.tsx` imports the shared module;
  mounted behind the *login* and behind the *shell*, so the door and the hall burn
  over one hearth.
- **Smíðja visualizer** — a `<canvas class="ember-bg">` behind every view.
- **Óðrerir** — a `data-ember` canvas in its shell, so the hall warms too.
- Sessrúmnir keeps its own React port untouched (two ports of one fire, the same
  physics; consolidating them on the shared module is the next tidy).

And the reference for the missing furniture: **Óðrerir already carries it all** —
four favicons, `mask-icon` in bronze, `site.webmanifest`, canonical, description,
theme-colour and Open Graph. The other apps should be brought up to *it*.

## 2026-09-16 — icons the operator can pin, and one pair of hands for the shells

**"Fail, no icons" — and the cause was a trap I had already been bitten by.**
`bin/design-icon.sh install` writes an app's rune into the icon theme and a
`.desktop` entry into the applications dir. It used `XDG_DATA_HOME`, and this
agent session exports that as a **sandbox** (`…/opencode-rd`), so the icons went
somewhere no desktop can see. It now targets the operator's real data dir
(`$HOME/.local/share`, with `YMIR_DESKTOP_DATA_HOME` for a throwaway test) — the
same class of bug that once hid `gh` from this session.

Installed now, for **every** app: hlidskjalf, **odrerir**, **sessrumnir**, the
Smíðja visualizer and hlidskjalf-mobile — each with its rune icon and a dockable
entry. Óðrerir and Sessrúmnir had **none**, which is exactly why they could not
be pinned. The stale `ymir-smidja.desktop` (pointing at a repo PNG) is folded
into the rune's own entry.

**One pair of hands for two lifecycles.** `scripts/start.sh` and
`scripts/stop.sh` manage the web; `scripts/electron.sh` manages the shells — and
they never met, which is why "the electrons are not running" was true while 28
processes stood, and why a restart could leave a shell watching a dead port.
`scripts/raise.sh` / `scripts/lower.sh` own both: lower takes the windows down
**first**, so none is left watching a port that just vanished.

**A bug the restart surfaced:** `scripts/electron.sh stop` used `local` outside a
function — it worked only because the assignment happened to be harmless, and it
printed a shell error on every stop. Fixed.

**And the inventory is a tool:** `bin/feature-inventory.sh` — 132 tools, 5 jobs,
26 skills, 20 agents, 8 workflows, 6 apps, 4 migrations, 6 registered projects,
each with the way it must be proven written beside it.

## 2026-09-16 — the icons are real runes now (eight of them were drawings)

The Allfather looked at the icons and said what no check had: *"the icons must be
based on real runes."* He was right, and the fault was in the **glyph set**, not
just in the two icons I had minted.

`midgard/design-system/icons.md` claims every glyph is an Elder Futhark rune and
gives each its unicode. **Eight of the twenty-one files were drawings** — a hall
(`valhalla`, which Óðrerir was wearing), a horn, a shield, a spear, a well, a
squirrel, a gate, a world-tree. Replaced with the real runes their own rows
declare:

```
gjallarhorn ᚷ Gebo · gungnir ᚦ Thurisaz · heimdall ᚺ Hagall · mimirsbrunn ᛜ Ingwaz
ratatoskr ᛒ Berkanan · utgard ᚢ Uruz · valhalla ᚹ Wunjo · yggdrasil ᛃ Jera
```

Gungnir was claiming Gebo, which Gjallarhorn already holds, so it takes
**Thurisaz** (the thorn — the spear) and `icons.md` is corrected to match.

**Five apps, five different runes:** Hlidskjalf `ehwaz`, mobile `raidho` (the
road), Óðrerir `valhalla`→ now genuinely `ᚹ Wunjo`, Sessrúmnir `sowilo`, Smíðja
`kaunan` (the torch). The install table drives both mint and install now — it had
been guessing paths, which is why the Smíðja visualizer had been given
Hlidskjalf's icon.

Also this pass: the visualizer gained its furniture (description, canonical,
manifest, OG + Twitter), Óðrerir's Electron shell asks for a window icon, and the
apple-touch PNGs are rasterised (ImageMagick is present).

## 2026-09-16 — the desktop never dials out: Cloudflare stays outside Electron

The Allfather's rule: **"electron should never have anything with cloudflare to
do."** It was not quite true — three doors stood open:

- **Sessrúmnir's "To the Hall"** preferred the local hall and, when it did not
  answer, fell back to `https://hall.ymir.zerwiz.org`. A desktop seat that
  reaches for a public hostname when its own machine is quiet is a seat that
  leaves the building to do its errands. It is now **local only** — when the hall
  is not running, the seat says so.
- **Hlidskjalf's shell** took `HLIDSKJALF_URL` and `SMIDJA_URL` from the
  environment, and **Óðrerir's** took `HALL_URL` — each able to point a desktop
  window at a tunnel with one exported variable.
- Both now pass their URL through a **loopback guard**: anything that is not
  `127.0.0.1`, `localhost` or `::1` is refused with a warning and replaced by the
  local default. The shell loads the machine, never the internet.

**Why this is the same fight as the bridge:** a desktop app that dials out is a
desktop app whose failures belong to somebody else's edge. The bridge disguised a
cloud endpoint as `127.0.0.1` and cost a night; these three would have disguised a
tunnel as a local seat.

## 2026-09-16 — the panels that crashed, the gate that lied, and the well that would not open

- **Statistics now reports the HARNESSES** (pi + opencode), not the smithy's runs.
  `bin/hlidskjalf-usage.sh` aggregates opencode's SQLite token store and both pi
  stores, and emits the numbers under the names the gate renders (`gate{}`):
  totals, usage, providers local/online with per_model, by_chain, by_model.
  Verified: 21,497 runs (opencode 21,422 · pi 75) · 331.5M tokens ·
  local 239,623 / online 331,289,420 · cache-hit 91.5%.
- **A failed fetch no longer takes the hall down.** Endpoints answering `{error}`
  were handed to panels as data — Rail read `.filter` on an object, Stats read
  `.totals` on a string, and both crashed. The store now runs every bootstrap
  answer through `ok()`: an error keeps the last good value.
- **`/api/usage` was answering with a traceback** while the script passed by hand:
  the gate process had been started before the fix and caches a failure for 60s.
  Restarted; the endpoint serves the harness numbers.
- **The engram MCP (`-32000: Connection closed`) is mended.** Not config, not the
  engram package: `python3.12 -c "import mcp"` failed because the system
  `python3-rpds-py` ships without its compiled `rpds.rpds` module, which
  `jsonschema` (inside `mcp` 1.x) imports. Mended with
  `python3.12 -m pip install --user --break-system-packages --force-reinstall rpds-py`
  (plus `mcp<2` under python3.12). The server now starts and waits on stdio.
  Eir should check this pair: `mcp` present for the interpreter that runs the
  binary, and `rpds` importable.

## 2026-09-17 — Sessrúmnir stops wearing Pi's clothes

- **The naming law, broken at the root.** Clicking the Sessrúmnir icon opened a
  window titled **Pi Desktop**: `apps/sessrumnir` is the Pi Desktop shell adopted
  whole, and its product name was still Pi's —
  `export const PI_DESKTOP_PRODUCT_NAME = 'Pi Desktop'` — rendered as the heading on
  the home screen, the sidebar and the chat panel. That is the title the Allfather
  saw, twice, on every launch.
- **Mended at the name:** `SESSRUMNIR_PRODUCT_NAME = 'Sessrúmnir'` (Odin's hall of
  many seats), the three rendering components walked, and the old constant kept as an
  alias so no unwalked import breaks. `tsc --noEmit` exit 0.
- **Still owed:** 1,255 English strings, **86 of them naming Pi** ("Pi is working",
  "Quit Pi Desktop", "Pi Desktop v{{latestVersion}} is available", "Start Pi/OMP
  before planning with Council"), and Pi's logo on the home screen. The locale is the
  one place they live — that pass is the order, not a patch.
- Also in the launcher this session: an icon click now raises THE SYSTEM (converge
  the service, reborn a windowless app, focus a live window), and `stop --view X`
  stops only X — the loop that killed every view is gone. The Hall's own outage had
  a cause: an Astro dev server on :4323 while the app waited on :4322.

## 2026-09-17 — the smithy can see the well

- **Why the memory looked absent in the smithy:** the visualizer proxies the bridge's
  `/inspect`, and `/inspect` reported three fields — store, episodes, agents — while
  the well holds six layers. A panel told only the episode count cannot show that
  facts, entities and reflections exist. `/inspect` now reports them all:
  episodes, facts (active/superseded), entities, edges, reflections (with the last
  run's time) and the vector index.
- **Through the smithy right now:**
  `store $YMIR_HOME/memory/kaia.engram · episodes 8 · facts 36 (35 active) ·
  entities 60 · edges 480 · reflections 1 (2026-09-16T21:01) · vec index 8`.
- **A trap found while doing it:** restarting the bridge RAW (`python3 bin/mimir-bridge.py`)
  loses the env that carries the well's path, and the bridge silently re-points at the
  old store in the repo — 364 stale episodes and no facts. The well is the **blessed
  starter's** to raise: `bin/mimir-bridge.sh --start`. A raw restart is a different
  well wearing the same port.

## 2026-09-17 — Skrymir opens the hoard, not the checkout

- **The file browser was rooted in the wrong tree.** `workspaceRoot()` built every
  realm path under `ROOT` — the checkout — so `work` resolved to a directory that does
  not exist and the walk fell back to the repo's `docs/`. That is why Skrymir showed
  `lore.md`, `Architecture.md`, `research/`, `runbooks/`, and why a file it had just
  listed answered **"not found"**: the listing came from one tree and the read from
  another.
- **The hoard first now (Rule 04):** `$YMIR_HOME/svartalfaheim/<realm>` → company
  container → `$YMIR_HOME/workspace/<realm>` → the checkout only as legacy. An empty
  realm shows the hoard's home, never the repo's docs. Verified: `work` lists
  `memory/daily/2026-09-13.md` and `workspace/`, and a read returns its body.
- Note for the next hand: the gate runs **without** `--watch` — a server edit is on
  disk and not in the process until `scripts/start.sh` raises it again.

## 2026-09-17 — the Fleet was a rack of terminals; now it is the roster

- **We were tracking the tools.** `.agents/agents/` holds **21 agent definitions** —
  Brokk, Sindri, Bragi, Forseti, Mímir, Kvasir, Snotra, Huginn, Hnoss, Sága, Muninn,
  Frigg, Gróa, Jörð, Sýn, Týr, Galdr… — and the Fleet served **13 panes all named
  "OpenCode"**, role `opencode`. The board showed seats and never the smiths who might
  be standing in them.
- **`bin/hlidskjalf-agents.sh` now reads the roster** (`.agents/agents/*.md`, canonical
  per RULES/02) and joins each agent to its standing pane: figure, craft, model from
  the definition's frontmatter, and `live{}` only when a pane answers to it. An
  **unseated agent is still an agent** — hiding it is what made the board a rack.
- Harness seats that answer to no one on the roster are kept visible and named
  honestly, never dressed as agents.
- Served: **34 entries — 21 agents (roster first) + 13 harness seats, 14 joined**.

## 2026-09-17 — the extensions deployed without their modules

- **pi would not start a seated worker, and the reason was a half-deploy.**
  The four shared pi extensions all reported
  `Failed to load extension: Cannot find module ./lib/<module>.ts` — and every one
  of those modules was present in the repo, one level away under the extensions'
  own `lib/`. The loader copied the top-level extension files and never their
  supporting modules.
- **Mended in two places.** (1) The missing modules are now beside the deployed
  extensions, so a running pi loads all four. (2) `bin/valknut-load.sh` — the
  loader — now deploys that lib alongside the extensions, idempotently (identical
  files untouched), so a fresh machine cannot hit it. A deploy that copies a file
  but not the module it imports is not a deploy.
- **What this cost:** the Forseti audit was seated on a **local** model, and the
  pane fell back to a bare shell when pi could not start — which is why the brief
  was typed at a prompt and answered `bash: syntax error near unexpected token '('`.
  With the extensions mended, pi's remaining blocker is the model: the llama-router
  has no raisable seat tonight (`:8080` unbound, and the installed llama.cpp cannot
  load the Apodex weights), so a local-first dispatch has nothing to reach.

## 2026-09-17 — the well as tools: Ymir's first custom pi extension

- **Why the extension tree was failing, from the upstream law:** pi auto-discovers
  extensions from BOTH the global home and the project-local tree. The same extension
  in both loads twice and pi refuses the duplicate tool —
  `Tool "gna_watch_arm" conflicts with …`. Ymir's own loader already says the shared
  extensions have **one** home; the tree contradicted it by carrying the extension
  files project-locally as well.
- **Built: `ymir-well`** — the well, as tools inside every pi session.
  `well_recall(query, k)` reads Kaia's memory before work begins;
  `well_observe(content, tags, actors, salience)` writes the lesson after. Written in
  the house voice, honest about failure (a failed write says the lesson was NOT
  written), and it sends tags as LISTS — a comma-string is stored as an array of
  characters, which is exactly how a recall once returned `['r','u','n']`.
- Authored in the SHARED source and deployed to the global home — one home, never a
  project copy. That is the pattern every future Ymir extension follows.

## 2026-09-17 — the duplicate extensions removed from the project tree

- **The fault, now measured exactly.** The project-local extension tree carried four
  files that the shared source also carries — `gna-pi-watch.ts`, `ro.ts`,
  `skuld-branch-supervision.ts`, `syn-turnend-guard.ts`. pi auto-discovers both the
  global home and the project tree, so each loaded twice and pi refused the second
  copy of every tool: `Tool "gna_watch_arm" conflicts with …`. Every `pi` start in
  every worktree died on it, which is why a seated worker fell back to a shell.
- **The fix:** those four files are gone from the project tree. What remains there is
  `lib/` — the modules the *global* extensions import — and its README. The
  extensions themselves live in the shared source and in the one global home.
- The seatbelt refused the plain shapes (`rm`, `mv`, `>`-bearing commands) on this
  path and named the remedy: *a reviewed commit*. This is that commit.

## 2026-09-17 — smoke test all UI: two checks that lied about their own subjects

- **The truth gate failed on my own change.** It demanded the connector's total equal
  the herdr pane count; the connector is roster-first now, so it legitimately reports
  agents AND seats (33 vs 13 panes). Panes are a subset of what the board must show.
  Corrected: a FAIL now means FEWER entries than panes — a standing seat hidden from
  the board — which is the fault worth catching. **Verdict: PASS.**
- **The smoke test reported a present database absent.** It looked for the smithy's db
  at the repo path; the runtime keeps it under `$YMIR_HOME/smidja/`, which is where
  the bootstrap and the gate both resolve it. Same wound as Skrymir and the well: the
  check and the owner disagreeing about where the record lives. **Now: OK, 8 tables.**
- **Smoke test all UI: 5/5 OK** — spa, api, well, smidja-db, loaders. Truth gate: PASS.

Also mended in the same pass: `StatusChip` read `STATUS_META[status].tone`, and the
fleet now reports a status it was never taught (`seated`), so an unknown status threw
and killed the gate. An unknown status can no longer take a panel down.

## 2026-09-17 — Glitnir stops hanging, and one process is one row

- **`/api/reviews` ran two 60-second shell checks on every poll**, so the review board
  hung for a minute and read as a dead surface. It is memoised for a minute now, the
  same discipline the usage endpoint already follows: a board a human reads does not
  need an answer fresher than its own usefulness.
- **`/api/processes` returns the same id twice** — `systemd:dbus` arrives from two
  sources, 45 entries for 44 processes. The panel dedupes by id, so a repeated process
  renders as the one process it is, and React is no longer handed a duplicate key.
  The duplicate at the source is recorded, not hidden.
- `/api/stream` answers 200; the live stream is not broken, it was the window.

## 2026-09-17 — the fleet stops colliding: a grid fan, and each smith's own house

- **The Fleet graph collided above ~8 agents.** `Fleet.tsx` fanned every
  non-hub agent into a single two-row line at ~4.4% pitch on 46px rings — with
  20 roster cards the rings and labels overlapped into an unreadable pile.
  `layout()` now fans a square-ish grid (`cols = ceil(sqrt(n))`, hub at top,
  rows pitched past ring+label), so 20 agents render separated.
- **Every ring showed the same rune.** `bin/hlidskjalf-agents.sh` hardcoded
  `domain: ymirlabs` for every card and its roster parser never read the
  `domain:` frontmatter each figure carries — so all twenty cards wore the
  anonymous ᛦ. The roster now parses `domain:` and passes it through;
  `galdr.md` names its house (`brokkforge`); the graph falls back to
  `DOMAINS.ymirlabs` only when a domain is genuinely unknown (was a crash)
  — and the `AgentCard` already fell back safely.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` — the
Fleet graph paragraph (grid fan, roster domains, fallback).

## 2026-09-17 — the apps leave the monorepo; installation pulls them from their own repos

- **The app split lands in the installer.** The five apps (hlidskjalf,
  hlidskjalf-mobile, odrerir, sessrumnir, smidja) now live in their own repos
  registered in the home registry (`$HOARD/identity/projects.yaml`) — the
  monorepo never tracks them, and **`step_apps`** clones or fast-forwards each
  `apps/<path>` from its registered `git{}` block (never guessing a remote,
  always reading the registry). The smithy engine (`apps/smidja`) is stamped
  from the cloned factory's `templates/smidja`, exactly as `install.py` does
  for a target repo — so a fresh clone still gets a working smithy.
- **The vendored app trees leave the index.** `apps/{hlidskjalf,
  hlidskjalf-mobile,odrerir,sessrumnir,smidja,smidja-factory}` are gitignored
  and `git rm --cached`-ed (751 files, 135k lines); `apps/README.md` stays.
  A dir present that is not a git clone is reported (`move it aside and
  re-run`) rather than silently replaced.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/installation.md` — the
step table (`22 steps`, `24` `step_*` functions), the new `apps` row, and the
Sessrúmnir rows now say "its own repo", not "vendored".

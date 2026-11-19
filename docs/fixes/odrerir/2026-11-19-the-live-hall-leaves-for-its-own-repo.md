## odrerir · 2026-11-19 — the Live Hall leaves for its own repo (split, not retired)

### Why
The Allfather: *"split ovredrir also"* (plan 04, Road B), with the whole split's word, *"we can not lose anything"*.

### What moved
`apps/odrerir/` (53 files) → `zerwiz/odrerir`, cut with `git filter-repo --subdirectory-filter`: every one of the 51
commits that touched it here, authors and dates kept. It locks its own dependencies now; it leaves Ymir's npm workspace
(22 lock lines; its React packages are shared with Hliðskjálf and stay).

### It stands alone
- **The cloth:** `hall.css` imported `midgard/design-system/tokens.css` and the ember background `ember.js` by climbing
  out of the app; the hall carries its own byte-identical copies (`src/house-design/`), kept equal by
  `bin/apps/tests/test_shared_copies.py`. Vite serves nothing outside the app (`allow: ['.']`), which is fault 1's guard.
- **A hidden tie:** `vite.config.ts` needs Node's types and never declared them; it borrowed `@types/node` hoisted into
  Ymir's workspace root. Standing alone its build failed (TS2307 `node:fs`). It declares `@types/node ^24` itself.
- **The live board is state:** `livehall.json` lived in the app's own `public/` and `dist/`; it now lives in
  `~/.local/state/odrerir/`, and each release links `public/livehall.json` and `dist/livehall.json` to it. Ymir's nightly
  hall-snapshot job is unchanged: it writes with a plain redirect, which follows the link.

The contract: `install.sh` (deps, esbuild's binary placed, the build, the board linked; `--check`), `start.sh` (vite
preview on `:4322`, the window through Ymir's desktop shell, a browser without it), `stop.sh`, `activate.sh` (the
launcher), `uninstall.sh` (never the board) and CI.

### Ymir's side
The release built Óðrerir unguarded (`npm run build -w apps/odrerir`) and would have died with exit 15 once it left; it
now builds it, links its board and seeds the board only while the hall is in the tree, and never recreates `apps/<app>/`
for an app's shared file. The icon tool and the desktop-class test read it wherever it is; `scripts/start.sh`, the shell
and the hall-snapshot job already found it through `app_dir`. AGENTS.md's governed table and the subsystem map name the
board's writer (`hall-snapshot.sh`, `nornir-job-hall-snapshot.sh`) in place of `apps/odrerir/**`. Kept lines are in
`config/split/odrerir.kept.tsv`. The registry: `contract: 1`, `moved: zerwiz/odrerir@<sha>`, `install_default: dev`.

### Proof
- `split-ledger.py verify odrerir`: 53/53 files, 51/51 commits, 18/18 fix notes, 0 ties owed — **nothing lost**.
- From the cut repo into a fenced apps home: the first install was refused red (the missing `@types/node`), nothing
  flipped; after the fix, install built, `--check` green, flipped, launcher seated.
- The installed hall served from its own home on a spare port: `/` 200, titled *Óðrerir — the Live Hall*, and
  `/livehall.json` answered from the state file through the link; then lowered.
- The cut is reproducible: the finalize step gives the same head twice.

### Owed
The window opened from the installed release through Ymir's shell, in DevTools, on two machines (fault 2 of 2026-09-18:
"the fourth hall had no window"); the move record in the home; pushing `zerwiz/odrerir` (its September head tagged
`pre-split-2026-09` first).

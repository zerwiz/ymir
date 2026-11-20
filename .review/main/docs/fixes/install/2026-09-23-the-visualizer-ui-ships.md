## install · unversioned · 2026-09-23 — the visualizer's built UI ships (the missing app view)

### Why
The Smiðja visualizer **installed, answered on `:8437`, and showed no interface**.
Its built `dist/` never reached the tarball — so the API served a page with
nothing in it. The Allfather saw it as "one of the apps in our app view did not
install correctly".

Three independent causes, each sufficient on its own:

1. **A blanket ignore.** `.gitignore` line 13 is `dist/`, and **npm honours
   `.gitignore` when no `.npmignore` exists**. So every built bundle under a
   `dist/` was silently dropped from the package.
2. **A build list that could not reach a nested app.** `bin/app-build.sh`
   defaulted to `(hlidskjalf odrerir sessrumnir)` and resolved each as
   `apps/<name>/`. The visualizer lives at
   `apps/smidja-factory/apps/visualizer` — nested, and never in the list.
3. **A pack that skipped the prepack.** `bin/npm-pretest.sh` packs with
   `npm pack --ignore-scripts`, so `package.json`'s `prepack` (which runs
   `bin/app-build.sh`) **never fired** — even for the apps that were listed.

### Fix
- **`.gitignore`** — un-ignore `apps/smidja-factory/apps/visualizer/dist/` and its
  contents by name. It is a build artifact, but it is also **part of the shipped
  product**, and npm reads this file.
- **`bin/app-build.sh`** — the default list gains
  `smidja-factory/apps/visualizer` (a nested path is joined onto `apps/`), so the
  visualizer is built like every other surface.
- **`bin/npm-pretest.sh`** — builds every surface **before** packing (the prepack,
  run for real, since `--ignore-scripts` skips it), and the **hull** gains
  `apps/smidja-factory/apps/visualizer/dist/index.html`, so a blank app view can
  never pass the gate again.
- **`package.json`** — `files[]` names the visualizer `dist/` explicitly.

### Verification
- The tarball now carries **73** `visualizer/dist` files (was **0**), including
  `index.html`, the JS/CSS bundle and the model icons.
- The hull entry is present in the packed artifact.
- `PRETEST PASS` — with the visualizer built and shipped, and the remote legs
  green on omarchy and whynot.

### Files
- `.gitignore`
- `bin/app-build.sh`
- `bin/npm-pretest.sh`
- `package.json`

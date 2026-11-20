# desktop · 2026-11-08 — an update could leave every machine with no Electron, and nothing mended it

## What

The Allfather, twice in one evening: *"we also get a problem of electron when updating. electron are
missing errors"* — and then the part that makes it a fleet fault rather than a local one: *"all updates on
all machines must solve this better for all kind of users"*.

npm 11+ **gates install scripts**, and Electron's postinstall is what downloads the binary. So an install
or an update can put the package in place perfectly and leave `node_modules/electron/dist` holding
nothing but `locales/`. Every desktop surface then fails to open with "electron missing".

Worse, three roads that were supposed to catch it did not:

- **the package's own `install.js` is not enough.** Measured here: with `dist/` empty it exits **0** and
  unpacks only `locales/` — a door that trusts it reports a lie.
- **the installer only warned.** `bin/engine/ymir-install.sh` printed *"electron has no binary — npm
  rebuild electron"* and left the work to the user.
- **the healer could see it and refused to mend it.** `bin/agents/eir-doctor.sh`'s `shells` surface
  reported `broken` and printed a remedy; `eir fix` could not fix it.
- **nothing on the update path looked at all.** Gróa fast-forwarded the tree and ran Eir's *check* — so an
  update could leave the fleet with no window and every row said "reported".

## The change

**One door, four callers: `bin/desktop/electron-ensure.sh`.**

```
bin/desktop/electron-ensure.sh status            # what every surface resolves (read-only)
bin/desktop/electron-ensure.sh ensure            # mend, then PROVE it with --version
bin/desktop/electron-ensure.sh ensure --root DIR # judge/mend the tree at DIR
```

Four roads, each verified by running the binary before the next is tried: `npm rebuild electron` → the
package's `install.js` → **the machine's own cached artifact, unzipped** → the artifact fetched. Only a
binary that answers `--version` counts as success.

Written for **every machine and every user**, not for this box: the artifact name is computed from the
platform and arch (`linux` · `darwin` · `win32` × `x64` · `arm64` · `ia32`), the cache is searched where
each OS puts it, `ELECTRON_MIRROR` and `ELECTRON_CUSTOM_DIR` are honoured for a mirror or a corporate
proxy, unpacking uses whatever the OS has (`unzip` · `tar` · `powershell`), a machine that set
`ELECTRON_SKIP_BINARY_DOWNLOAD` is a **skip with its reason** (a headless server deliberately carries no
window), and a surface that is not installed at all (`--no-desktop`) is a skip, never a failure.

Wired into every path that can move the tree, so the fault cannot come back through a door that was not
told:

- `bin/engine/ymir-install.sh` — the desktop step **mends** instead of warning (a `--check` run still
  only reports).
- `bin/agents/groa-update.sh` — **after every update**, before Eir judges, and never fatal.
- `bin/agents/eir-doctor.sh` — `fix` now really fixes the `shells` surface.
- `bin/engine/release-build.sh` — a release lands its runtime through the same door (its earlier inline
  chain is gone; one implementation, four callers).
- **`.npmrc` at the repo root** — `allow-scripts=electron,node-pty,esbuild`. The approval belongs to the
  repository, so it is true for every user and every clone, instead of depending on whoever edited
  `~/.npmrc` on one machine.

## Proved

A fixture that reproduces a gated install — the electron package present, `dist/` holding only `locales/`:

```
$ bin/desktop/electron-ensure.sh ensure --root /tmp/el-fixture
  "hlidskjalf","mended","/tmp/el-fixture/node_modules/electron/dist/electron"
  "odrerir","skip","not installed in this tree (a web-only / --no-desktop install is a recorded decision)"
  "ok","every installed surface resolves an Electron that answers --version"
$ /tmp/el-fixture/node_modules/electron/dist/electron --version
v33.4.11
```

Three seconds, from the machine's own cache, no network. `install.js` was tried first and — as measured
— left only `locales/`; the door noticed because it verifies, and moved to the next road.

Against the live release, every surface resolves the binary the release itself carries:

```
  "hlidskjalf","ok","…/ymir-releases/e08e15bf0f66/node_modules/electron/dist/electron"
  "odrerir","ok", …   "sessrumnir","ok", …
```

A tree with no desktop app, and a machine with `ELECTRON_SKIP_BINARY_DOWNLOAD=1`, both print `skip` with
their reason instead of a false green. Eir on the installed tree: `"shells","ok","hlidskjalf ok; odrerir
ok; sessrumnir ok"`.

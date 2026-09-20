## sessrumnir · unversioned · 2026-09-18 — the platform fetches its own Electron runtime (a user needs no help)

### Why
- **npm gates install scripts**, so Electron's postinstall never runs and the desktop
  windows cannot open: a whole install with no windows, and no error a user could act on.
- Every npm-shaped cure failed its own way: `npm rebuild electron` reports *"rebuilt
  dependencies successfully"* and changes nothing; `npm install-scripts approve` does not
  exist in every npm; `--allow-scripts` works only at install time, and npm skips
  unchanged packages.
- **What works everywhere is what the postinstall does:** fetch the release and place it.
  `electron_fetch_runtime` (`bin/electron-lib.sh`) reads the version from the app's own
  manifest, fetches that release, places `dist/`, writes `path.txt`, and checks the
  binary. Both mends fall back to it.
- **Proven on this machine:** the runtime removed, the mend run, `v43.0.0` present and
  answering.

### Files
- `bin/electron-lib.sh`

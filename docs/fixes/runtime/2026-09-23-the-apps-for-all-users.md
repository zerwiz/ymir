# runtime · 2026-09-23 — the apps for all users (npm-world launches)

## Why
A seat's desktop entries pointed at the repo tree and the launchers' mend
never seated a fresh install's apps: npm's policy skips dev-deps and gates
the electron download, so the npm package's apps arrive with no node_modules
and no runtime — the windows never open, and the entries' repo-path Exec was
wrong for anyone running from the npm installation.

## What
- `bin/desktop-place.sh` — the placement resolves the RUNTIME root: when the
  `ymir` CLI resolves into the npm package, the entries' __YMIR_ROOT__ becomes
  the package's own root (its scripts + bin); else the repo. The apps run from
  the npm installation, whichever it is.
- The mend's tiers (both `scripts/electron.sh` and `bin/sessrumnir.sh`):
  npm install --include=dev (the deps) -> approve + rebuild -> the
  postinstall's install.js -> `fetch_electron_zip` (the PROVEN direct zip +
  unzip road, `bin/electron-lib.sh`), so a fresh dash boots itself.
- Proven on omarchy from the npm package: hlidskjalf up :3888, odrerir up
  :4322, smidja up :8437, sessrumnir up; 178 M runtime seated by the zip road.

## Files
- `bin/desktop-place.sh` · `scripts/electron.sh` · `bin/sessrumnir.sh`
- `bin/electron-lib.sh`

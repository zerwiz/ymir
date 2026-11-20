## sessrumnir · unversioned · 2026-09-20 — the seat-hall wears its whole face again

### Why
- **The seat showed only the ember — no logo, no buttons, no layout.** The
  renderer's `out/` build predated the ember's anchoring fix (built 09-18, the
  fix landed 09-19 in *the ember: the canvas was one pixel wide*): in the stale
  build the hearth canvas rode as a plain flex child at full window size, so it
  pushed the entire hall (logo, Open Folder / New Session / New Task, the streak
  board) below the fold. The source already declared
  `pointer-events-none absolute inset-0 -z-10`; the shipped artifact simply did
  not carry it. Rebuilt the renderer from current source (`electron-vite build`)
  — verified by DevTools DOM inspection and by the window's own face: the full
  landing renders with the ember anchored behind it.
- **The rebuild tripped a quiet trap:** `electron-vite` resolves the Electron
  major version from the workspace root (hoisted), where `electron` is not
  installed, and failed with `getElectronMajorVer`. The build script now sets
  `ELECTRON_MAJOR_VER` from the app's own `electron` package, so a clone rebuild
  (and a future publish) works without the escape hatch. A fresh npm publish of
  a surface carries this build automatically — `out/` is a gitignored artifact,
  regenerated here.
- **The window's class is `ymir-sessrumnir` now**, not `sessrumnir` — the seat
  shares the house naming with the other halls. The door's focus spell
  (`bin/sessrumnir.sh`) still hunted the old class, so a click on the icon could
  not raise an already-running window. Mended to `^ymir-sessrumnir$`; the
  `.desktop` entry's `StartupWMClass` already named it right.

### Files
- `apps/sessrumnir/package.json`
- `bin/sessrumnir.sh`

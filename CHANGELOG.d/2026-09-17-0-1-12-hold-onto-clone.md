## 2026-09-17 — 0.1.12: the icons reach the live tree, and a missing surface is a failure

- **The launcher entries name the door** (`Exec=ymir hlidskjalf`, …) instead of an absolute path into whichever tree minted them — the fault that made every icon do nothing.
- **All three npm shapes resolve**: a clone (`apps/<app>`), a nested package, and a **sibling** package (`<prefix>/lib/node_modules/@zerwiz/<app>`), which is where a global install puts a dependency it hoists out of the distro.
- **@zerwiz/sessrumnir pinned exact** — a prerelease range resolved in one prefix and was skipped in another.
- **A missing surface is a FAILURE with the remedy**, never "skipped".

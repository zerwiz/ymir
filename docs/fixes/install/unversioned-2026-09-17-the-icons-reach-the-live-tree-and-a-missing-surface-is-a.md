## install · unversioned · 2026-09-17 — the icons reach the live tree, and a missing surface is a failure

### Why
The Allfather clicked the launcher icons and nothing happened. Both faults were
mine, and both are the same mistake wearing different clothes: **something named a
path where it should have named a door.**

- **The entry launched a temp directory.** Every `.desktop` file carried
  `Exec=bash <the tree that minted it>/scripts/electron.sh …` — and I had minted
  from `/tmp/opencode/…` while testing, so every icon on his launcher pointed into
  a scratch tree. Entries now name the **door**: `Exec=ymir hlidskjalf`, resolved
  from PATH, so a click reaches whichever install is live. A launcher entry must
  outlive the tree that wrote it.
- **The fourth surface was missing and the raise shrugged.** `Sessrúmnir — skipped
  (the sessrumnir surface is not present)` and the raise carried on. It was a
  **sibling**: npm put it at `<prefix>/lib/node_modules/@zerwiz/sessrumnir`, beside
  ymir, not inside it. The resolver knew a clone (`apps/<app>`) and a nested
  package (`<pkg>/node_modules/@zerwiz/<app>`) but not that third shape — which is
  the one a **global** install uses when it hoists a dependency out of the distro.
  All three are resolved now, and a surface that is absent is a **FAILURE with the
  exact remedy**, never a shrug.
- **A dependency must resolve every time.** `@zerwiz/sessrumnir` was declared as a
  prerelease range (`^0.1.8-alpha`): npm resolved it in one prefix and sk

### Files
- *(carried from the frozen CHANGELOG.md)*

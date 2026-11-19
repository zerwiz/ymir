## bilskirnir · 2026-11-19 — the window carries its own Electron

### What was wrong

The hall was installed into its own home for the first time on a dev machine: `bin/apps/apps.sh install bilskirnir`
cloned `zerwiz/bilskirnir`, built `releases/7a546ae0d2f9`, and its `--check` was green. Then the window would not open.
`start.sh --check` printed `electron                     none found`.

### The cause

Two faults, both left over from the hall's life inside Ymir's tree:

- **No Electron was declared.** In Ymir's tree, npm hoisted Hliðskjálf's Electron (`43.8.9`) to the workspace root,
  and the hall's window borrowed it. The hall's own `package.json` never named Electron, so in its own home there
  was none.
- **The resolver climbed out of the app.** `start.sh` found Ymir's `bin/desktop/electron-lib.sh` at `$APP/../..`. In
  `~/.local/share/ymir-apps/bilskirnir/releases/<sha>` that climb lands in the apps home, which holds no library.

`install.sh --check` did not look for Electron, so the install reported green over a window that could not open.

### The fix (in `zerwiz/bilskirnir`, commit `555375d`)

- `package.json` declares `electron` `43.8.9`, the house pin Rödd uses, and the lock carries it.
- `install.sh` places the runtime after `setup.sh`. Setup installs with `--ignore-scripts`, so Electron's postinstall
  never fetches the runtime. Ymir's `electron_fetch_runtime` places it, and Electron's own `install.js` is the road
  when Ymir is absent. `--check` now fails, by name, when the window has no Electron.
- `start.sh` resolves Electron with the library from `TREE` (`scripts/ymir-root.sh`), and uses the release as the
  workspace root.

No Ymir code changed. The fix is the app's own, built on the same pattern as Rödd's `install.sh`.

### Proof, on the dev machine

- The fixed ref built into a release and passed `--check`: `bilskirnir: ready (setup current, web/dist and server/dist
  built, Electron in place)`. The release flipped, with `previous` kept.
- `start.sh` exited 0 with `the window  open (http://127.0.0.1:8787)`. Hyprland listed a mapped window of class
  `ymir-bilskirnir`. Its process ran `releases/<sha>/node_modules/electron/dist/electron`, and `window.log` said
  `DevTools listening on ws://127.0.0.1:9415/…`.
- `apps.sh rollback` worked twice (there and back), then `check` was green. `stop.sh` lowered all three pieces, and a
  fresh `start.sh` mapped the window again.

### Owed

- Push `zerwiz/bilskirnir` with this commit. It sits on the local branch `eindri/e2e-bilskirnir` in the apps home's
  clone (`~/.local/share/ymir-apps/bilskirnir/repo`), and is not pushed. The installed release is built from it.
- Acceptance on a second machine, once the app's `main` carries the commit.

## CHANGE LOG

- 2026-11-19 — written.

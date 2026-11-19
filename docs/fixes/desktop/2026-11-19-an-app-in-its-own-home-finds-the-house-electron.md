## desktop · 2026-11-19 — an app in its own home finds the house's Electron

### Why

After the split, Óðrerir installs into its own home, `~/.local/share/ymir-apps/odrerir/current`. Its window is
the house's desktop shell (`scripts/electron.sh --view odrerir`), and the app ships no Electron of its own.

`electron_bin` looked for a runtime by climbing from the app towards `/`, then in a sibling package. An app in
its own home is no longer under the Ymir tree, so neither road reached the root's `node_modules/electron`.
Measured on the dev machine before the fix:

```
electron_bin ~/.local/share/ymir-apps/odrerir/releases/e01d8eb23c4e ~/ymir-runtime odrerir   → rc=1
```

`scripts/electron.sh start --view odrerir` would therefore stop at "no Electron runtime for odrerir".

### The fix

`bin/desktop/electron-lib.sh`: `electron_bin` and `electron_pkg_dir` gain a fourth, last road — the root's own
`node_modules/electron`. The major-version check still applies, so an app that declares another Electron major
is still refused the house's runtime.

### Proof

- `tests/test_electron_home_app.sh` — four cases; the first two are red on the old library and green now.
- The window, from the home: `YMIR_ALLOW_WORKTREE_RUNTIME=1 scripts/electron.sh start --view odrerir` printed
  `"odrerir","up",3494204,"http://127.0.0.1:4322/"`, the process ran
  `…/node_modules/electron/dist/electron … /home/<user>/.local/share/ymir-apps/odrerir/current`, and the
  compositor held a mapped window of class `ymir-odrerir`, title `Ymir · Óðrerir`.

## sessrumnir · 2026-11-19 — the launcher's stays test is fenced from the installed app

### Why

`bin/desktop/tests/test_sessrumnir_stays.sh` builds a small fixture app and a stand-in for Electron. It
then proves that the launcher says "up" only when the window stayed. Two faults hid behind each other:

- **It was not fenced from the apps home.** Once `bin/apps/apps.sh install sessrumnir` had run on this
  machine, the resolver's `home` road (`…/ymir-apps/sessrumnir/current`) won over the fixture. The test's
  own log then read `app=/home/<user>/.local/share/ymir-apps/sessrumnir/releases/133a42991a0c`, so the test
  was proving the installed app, not its fixture. The "dies in 1 s" case failed about one run in two.
- **The fixture could never pass the stale-build ward.** Plan 283 made the launcher refuse a tree with no
  `out/renderer/index.html`. The fixture had none, so once fenced it was refused at once:
  `build: no out/renderer/index.html at all`. It had only looked green because it ran a real app.

### What changed

- The test exports `YMIR_APPS_HOME` to an empty folder under its temp dir and unsets
  `YMIR_APP_SESSRUMNIR_DIR`, so only the fixture can be found.
- The fixture carries `out/renderer/index.html` and no `src/`, which the ward reads as a package copy.
- A new case proves the root fix in `2026-11-19-the-seat-borrows-ymir-from-its-launcher.md`. It lays the
  app out as the apps home does and checks that the window is handed the Ymir tree. It runs when the app
  build carries the fix, and otherwise prints a `skip:` line naming what is owed. `SESSRUMNIR_JS` names a
  checkout to prove.

### Proof

- `bash bin/desktop/tests/test_sessrumnir_stays.sh` → `rc=0`, with the root case skipped against the
  installed build.
- With `SESSRUMNIR_JS=<patched checkout>/bin/sessrumnir.js`, three runs in a row → `rc=0`, ending
  `ok   from the apps home the window is handed Ymir's tree (<this checkout>)`.

### Left open

The launcher reaps every process matching `/electron/dist/.*sessrumnir` before it starts. Run on a desk
where the real window is open, this test therefore closes that window. Close the window first, as was done
here.

## CHANGE LOG

- 2026-11-19 — written with the change.

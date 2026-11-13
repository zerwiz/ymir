## desktop · 2026-11-14 — every app opens on the desktop you opened it from

### Why

The Allfather asked: *"make so all apps open on the screen the user opens them in on omarchy."* Ymir pinned
Hlidskjalf, Smíðja, Sessrúmnir and Óðrerir to desktops 5–8 (`~/.config/hypr/ymir-desktops.lua`), the start scripts
jumped the view to whichever desktop a running window sat on, and the editor door sent files to an empty desktop.
An app opened from desktop 1 appeared somewhere else.

### What changed

| Place | Before | Now |
|---|---|---|
| `bin/desktop/ymir-app` | started the app | reads the desktop at the click, then brings the app's window there (new or already open) and focuses it |
| `bin/desktop/desktop-place.sh` | wrote one pin per app | writes no pins; `YMIR_DESKTOP_PIN=1` keeps the old layout |
| `scripts/electron.sh`, `bin/desktop/sessrumnir-launch.sh` | jumped to the window's old desktop | skip the jump when `ymir-app` is bringing the window (`YMIR_APP_FOLLOWING=1`) |
| `bin/engine/ymir-edit.sh` | default `free` (an empty desktop) | default `here`; a reused window is brought to you; `--desktop free` keeps the old road |

`YMIR_APP_FOLLOW=0` turns the follow off.

### Proof

On heimdall: Bilskirnir sat on desktop 2, `ymir-app bilskirnir` was run from desktop 1, and the window moved to
desktop 1 and took focus. `desktop-classes`, `ymir-edit-display` and `app-folder` tests pass.

The one-line change in `sessrumnir-launch.sh` rides in the plan 283 commit, which stages the same file.

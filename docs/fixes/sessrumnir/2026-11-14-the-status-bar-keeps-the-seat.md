# sessrumnir · 2026-11-14 — the status bar keeps the seat, not the other apps

**Component:** sessrumnir · **Branch:** `eindri/hall-follow` (plan 275, items 30 and 33)
**Files:** `apps/sessrumnir/src/renderer/src/components/status-bar.tsx`,
`apps/sessrumnir/src/main/index.ts`

## Why

At the Allfather's word, relayed as plan 275 items 32 and 33: the status bar still carried
**To the Hall**, and the menu still carried "Go to Hlidskjalf" and "Go to Smiðja". Those are
buttons that raise another app — the same hosted-era jumps removed from Hlidskjalf, Smíðja and
Óðrerir. Every app opens from its own desktop icon now.

Item 30 also reaches this window: "Sign in to Ymir…" and "Sign out of Ymir" were the gate's
login, and the gate no longer has one.

## What changed

- **`statusBar.tsx`**: the `openHall()` handler and its button are removed, with the now-unused
  `ExternalLink` import. The sidebar toggle, the terminal toggle, compact, cost, settings and the
  engine/status chips all stay exactly as they were.
- **`main/index.ts`**: `raiseHall()`, `signOutOfYmir()`, the `YMIR_GATE` constant, the
  "Go to Hlidskjalf", "Go to Smiðja", "Sign in to Ymir…" and "Sign out of Ymir" menu items are
  removed. The File menu keeps new session, new workspace, open project and quit; the Edit/View
  menus are untouched.

## How it was proved

```
npx tsc -b --noEmit (apps/sessrumnir)  → no error in the two files touched
                                         (three pre-existing errors remain in
                                          src/shared/bridge-http.ts and file-tree.tsx — present on
                                          main before this change and untouched here)
npm run build (electron-vite)          → exit 0, out/{main,preload,renderer} written
grep -n "toTheHall\|openHall\|raiseHall\|Sign out of Ymir" apps/sessrumnir/src → nothing
```

The window was raised from the pin and read through DevTools: the status bar shows the sidebar
and terminal toggles and no "To the Hall" text, and the File menu (inspected through
`Menu.getApplicationMenu()`) has no Go-to/Sign-in items.

## Not done, named

- **`system.hallUrl` in the preload** is left in place: it is a local URL probe, not a button,
  and removing an IPC door is not what item 33 named.
- **`resources/locales/en/translation.json`** keeps the `statusBar.toTheHall*` strings. They are
  unreferenced now; a translation file is generated and checked by `i18next-cli`, so the strings
  are removed with the next extraction rather than by hand here.

## CHANGE LOG

- 2026-11-14 — To-the-Hall button, the two "Go to …" menu items and the gate sign-in/out removed.

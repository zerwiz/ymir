# smidja · 2026-11-14 — the smithy's header keeps its own house

**Component:** smidja · **Branch:** `eindri/one-hlidskjalf` (plan 275, item 2)
**Files:** `apps/smidja-factory/apps/visualizer/src/App.vue` (+ its tracked `dist/`)

## Why

At the Allfather's word, plan 275 §2026-11-14 02:50: *"all apps that taking one app to another
in the header etc can also go. we open the apps from the desktop icons instead."* Smíðja's
header carried the same rune switcher as Hlidskjalf, the "To the Hall" door, a speed-start
Hlidskjalf button, and a label that read like a hall name.

## What changed

The cross-app doors are gone from Smíðja's header:

- the rune switcher **ᚺ ᛊ ᛋ** and its `raiseApp` helper;
- the **"ᛟ To the Hall"** anchor and the `hallUrl`/`host` it needed;
- the **speed-start "Open Hlidskjalf"** window button beside the window controls.

**About "fensalir".** The brief listed it among the header links. It was not a link: it was the
visible text of the **theme toggle** (`fensalir` · `classic` · `high-contrast`). A feature is not
removed here — the theme switching stays — but its visible label is now a palette glyph **◐** so
the header no longer shows a hall name where an app door used to be. The active theme's name is
still announced in the button's `aria-label`, so nothing is lost to a screen reader.

The rebuilt `dist/` is committed because the visualizer serves from it (the repo tracks it on
purpose); without the rebuild the running app would still carry the old header.

## How it was proved

A real Electron window, my own instance with a private `--user-data-dir`
(`/tmp/ymir-oneseat-smidja`) and `--remote-debugging-port=9334`, loading the worktree visualizer.
The operator's own apps were not restarted (`bin/desk/in-call.sh holder` printed nothing).

Through DevTools:

```
switchHallGroup 0 · openHlidskjalf 0 · toTheHall false
fensalirVisible false · hallLinks4322 0 · themeToggleText "◐"
themeToggleAria  "Theme: fensalir — the carved cloth"   (kept, not visible)
```

The screenshot shows the header starting at "Smíðja › sessions › memory › …", with **no
File/Edit/View menu row** and no rune switcher.

Static checks:

```
vue-tsc --noEmit (visualizer)   exit 0
vite build   (visualizer)       exit 0
```

## Not done, named

The `ᛉ <login>` / "Sign in" link to the gate is kept. It is the sign-in identity, not an app
door, and the brief did not name it.

## CHANGE LOG

- 2026-11-14 — Smíðja header: rune switcher, To the Hall, and speed-start Hlidskjalf removed;
  the theme toggle's misleading "fensalir" label replaced with a palette glyph; dist rebuilt.

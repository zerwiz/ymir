# odrerir · 2026-11-14 — the Live Hall hides Electron's menu bar

**Component:** odrerir · **Branch:** `eindri/one-hlidskjalf` (plan 275, item 5)
**Files:** `apps/odrerir/electron/main.cjs`

## Why

At the Allfather's word, plan 275 §2026-11-14 02:50: *"some of the apps are showing electron's
header."* Óðrerir's window carried the default Electron menu bar (`autoHideMenuBar: false` plus a
built menu), unlike Bilskirnir and Sessrúmnir, which hide it.

## What changed

One call, matching Sessrúmnir's pattern exactly: `win.setMenuBarVisibility(false)` once the
window exists. The application menu is still set (`Menu.setApplicationMenu`), so its accelerators
— reload, DevTools, zoom, fullscreen — keep working; only the visible bar is hidden.
`autoHideMenuBar` is deliberately left off so pressing Alt does not reveal it.

## How it was proved

A real Electron window, my own instance with a private `--user-data-dir`
(`/tmp/ymir-oneseat-odrerir`) and `--remote-debugging-port=9335`, loading the live hall on
`:4322`. The operator's Óðrerir process (`~/.config/ymir-odrerir`) was not restarted
(`bin/desk/in-call.sh holder` printed nothing).

The screenshot of that window shows the page's own header — "ᛉ YMIR · ÓÐRERIR — THE LIVE HALL" —
directly under the title bar, with **no File/Edit/View menu row**.

## Not done, named

Óðrerir's own in-page hall nav (its "Hlidskjalf · Smíðja · Sessrúmnir" chips) is untouched: this
errand named the menu bar for Óðrerir, and the cross-app header links for Hlidskjalf and Smíðja.

## CHANGE LOG

- 2026-11-14 — Óðrerir's visible Electron menu bar hidden; menu and accelerators retained.

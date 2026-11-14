# hlidskjalf · 2026-11-14 — one Hlidskjalf, no modes, and one way to Skírnir

**Component:** hlidskjalf · **Branch:** `eindri/one-hlidskjalf` (plan 275, items 2 & 5)
**Files:** `apps/hlidskjalf/src/app/Topbar.tsx`, `src/app/Rail.tsx`,
`src/components/AccountMenu.tsx`, `src/components/Halls.tsx`,
`src/data/realms.ts`, `src/state/store.ts`, `electron/main.cjs`

## Why

At the Allfather's word, plan 275 §2026-11-14 02:50: *"we should not have this any more.
only one runtime of hlidskjalf. and all apps that taking one app to another in the header etc
can also go. we open the apps from the desktop icons instead."* The measured row named the
**Work · Personal · the third realm chips** in the top bar as the modes.

## What changed

**One runtime, no modes.** The workspace-mode chips and every door that switched them are
gone. The chips lived in the top bar; the same switch also sat in the rail footer ("Tenants")
and in the account menu ("Workspaces"). All three are removed, and the active realm is pinned
to the single `DEFAULT_REALM` (`work`) so a stale `ymir.workspace` preference cannot resurrect
a second runtime. `WORKSPACES` in `realms.ts` is now a one-entry lookup for
`realmDef`/`realmById`, not a list of modes. Nothing else about the workspace scope changed:
search, files, the fleet and the profile still read the one active realm.

**No cross-app header links.** The rune switcher (ᚺ ᛊ ᛋ), its `HallsSwitcher` export, and the
"ᛟ To the Hall" button are gone from the top bar. Apps open from their desktop icons now.

**One way to talk to Skírnir.** The top-bar "Skírnir – Tala" button was a second door to the
page of the same name. It is removed; the Skírnir page, reached from the gate rail, is the one
way. Snotra's live recording ("Start listening") stays in the top bar, standing alone and
clearly separate — it records a meeting, it is not the assistant.

**No Electron menu bar.** `win.setMenuBarVisibility(false)` is called once the window exists,
exactly as Sessrúmnir does. The application menu stays set, so its accelerators (Ctrl+1/2/3,
reload, DevTools, zoom) keep working; only the visible bar is hidden. `autoHideMenuBar` is left
off so Alt does not reveal it.

## How it was proved

A real Electron window, my own instance with a private `--user-data-dir` (`/tmp/ymir-oneseat-hlidskjalf`)
and `--remote-debugging-port=9333`, loading the built worktree app. I did not touch the
operator's running app (`bin/desk/in-call.sh holder` printed nothing — the desk was free — and
the operator's `~/.config/ymir-hlidskjalf` process kept its pid throughout).

Through DevTools (`Runtime.evaluate` against `http://127.0.0.1:9333/json`):

```
wsSwitch 0 · wsChip 0 · realmSwitch 0 · accountTenants 0
runeButtons 0 · toTheHall false · skirnirTopbar false · snotraLiveBtn 1
```

The screenshot of that window shows the app top bar directly under the title bar — **no
File/Edit/View menu row** — with "Start listening" present and no rune switcher.

Static checks in the worktree:

```
tsc -p apps/hlidskjalf/tsconfig.json --noEmit      exit 0
vite build (apps/hlidskjalf)                       exit 0
```

## Not done, named

`HallsChooser` (the post-login "take your seat" modal on the web door) is left in place: it is
not a header link, and a desktop seat never shows it (`isDesktopSeat()` starts `choosing` false).
The brief named the header links, so nothing beyond them was removed.

## CHANGE LOG

- 2026-11-14 — modes and their three switching doors removed, one runtime; cross-app top-bar
  links and the duplicate Skírnir button removed; Electron menu bar hidden.

# odrerir · 2026-11-14 — the hall's header carries its own doors, not the other apps'

**Component:** odrerir · **Branch:** `eindri/hall-follow` (plan 275, item 32)
**Files:** `apps/odrerir/src/App.tsx`, `apps/odrerir/src/hall.css`

## Why

At the Allfather's word, relayed as plan 275 item 32: the Live Hall's header still carried the
four buttons that raise the other Ymir windows (ᚺ Hlidskjalf · ᛊ Smíðja · ᛋ Sessrúmnir · ᛟ
Óðrerir). They are the same cross-app jumps that left Hlidskjalf and Smíðja under item 2/11 —
an app opens from its own desktop icon, and a header that launches its siblings is a second
launcher nobody asked for.

## What changed

The `HALLS` list, `raiseHall()`, `isDesktopSeat()` and the whole `hall-btns` group are gone from
`App.tsx`, together with the `halls buttons` line in its header comment. What stays is the
hall's **own** nav: the board, the near loop, the tickets and the plans (`DOORS`), and the
mast. The now-unused `.hall-btns` rule is removed from `hall.css`; `.hall-btn` is kept, because
other panels of the hall still use the class.

## How it was proved

```
npx tsc --noEmit (apps/odrerir)   exit 0
npm run build   (apps/odrerir)    exit 0 — dist/index.html + assets written
grep -n "raiseHall\|/api/desktop\|HALLS" apps/odrerir/src → nothing
```

The window was opened from the built app and read through its own DevTools: the header shows
the mast and the four doors, and no `.hall-btns` group exists in the DOM
(`document.querySelectorAll('.hall-btns').length === 0`).

## Not done, named

- **The halls' own windows are still raised** by the Omarchy key bindings and by
  `scripts/electron.sh` — those are the desktop launcher, which is the road the Allfather
  named. Only the in-app buttons are removed.

## CHANGE LOG

- 2026-11-14 — the cross-app header buttons and their `raiseHall` door removed; the hall's own
  nav kept.

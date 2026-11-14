# The hearth had one pixel, and three homes

**Date:** 2026-11-13 · **Component:** sessrumnir · **Door:** `apps/sessrumnir/src/renderer/src/components/ember-background.tsx` · **Plan:** 283

## What was wrong

The Allfather, for the third time: *"sessrumnir are having problem with the ember again. its not on
the start interface and the chat dont have it from the bottom. we have old plans of this and fixed it
several of times."*

Two faults, both measured in the running app through its DevTools door (`YMIR_DEVTOOLS_PORT`, plan 275 S16).

**The chat's fire was one pixel.** The canvas mounted while its column was hidden, was sized 1×1, and
never sized again. It stayed 1×1 in the chat: `getBoundingClientRect()` = `1×1` at the canvas's own
corner, one warm pixel in the whole buffer. The landing's canvas did draw (25,662 warm pixels), which is
why the fault looked like "the chat only".

The cause is a fact about `<canvas>`: it is a *replaced* element, so `position:absolute; inset:0` does
**not** stretch it — its layout size is its `width`/`height` attributes, i.e. the drawing buffer. The
component set those to `1` at the hidden mount and depended on `size()` running again.

**Three implementations, so every repair landed in the wrong one.** The app carried
`ember-background.tsx` (live), a dead `EmberBackground.tsx` twin one keystroke away, and an unused copy
of `midgard/design-system/ember.js`. `grep EmberBackground` matched the dead twin first. Hlidskjalf had
the same dead twin in `src/app/`.

## What was forged

- **One file per app.** Deleted the two dead/dark copies in Sessrúmnir and Hlidskjalf's dead twin.
  `ember-background.tsx` is the app's only hearth and says so in its own header.
- **The canvas fills its host.** `style={{ width: '100%', height: '100%' }}` — layout comes from CSS, the
  drawing buffer from `size()` at dpr. The two are no longer the same number.
- **A mount with no box is retried.** If `getBoundingClientRect()` is empty, the component asks again
  every 250 ms until the column exists, then seeds and draws. A hidden mount can no longer silence it.
- **The fire rises from the floor.** Half the embers are seeded inside the lower half of the column, the
  rest just under the floor, so the view is alight on its first frame instead of after the seconds one
  ember needs to climb into sight. A resize draws one frame at once, so a pane split never shows a cold
  hearth.

## What each machine showed (heimdall, 2026-11-13)

| | pinned build (before) | checkout build (after) |
|---|---|---|
| chat canvas | **1×1 px**, 1 warm pixel | **1534×907 px** (buffer 1246×737) |
| chat, first look | no fire at all | 19,825 warm pixels, 99 % in the lower 60 % |
| chat, 25 s later | — | 16,765 warm pixels, still alive and rising |
| start interface | 721×167 px, 25,662 warm pixels | 888×975 px, 243,085 lit pixels |
| typecheck | 5 pre-existing errors | 5, same files, none changed here |

The "after" numbers come from the checkout's own build, run from the checkout, probed at
`127.0.0.1:9333` (`/json/list` → `Runtime.evaluate`), and captured with `Page.captureScreenshot`.
nidavellir's own row is appended to plan 283 when it was measured.

## The launcher now refuses a stale build

`bin/desktop/sessrumnir-launch.sh` names the tree and the build on every start, and refuses a build older
than its source instead of opening yesterday's app and letting the operator report the wrong fault. Its
own words, measured on this checkout before the rebuild:

```
error: Sessrúmnir will not start a build that is behind its source
  tree:   /home/heimdall/ymir/apps/sessrumnir
  build:  2026-10-31T00:43   source: 2026-11-13T20:21
help: (cd /home/heimdall/ymir/apps/sessrumnir && npm run build)   (or start the pinned app: …)
```

`SESSRUMNIR_ALLOW_STALE=1` starts it anyway and says so; a packaged copy (no `src/`) reports `package
copy` and passes, because a clean skip with its reason is a pass.

## The ward that keeps it from coming back

`bin/gates/guards/hearth-guard.sh`, in the one ward list (`bin/gates/guards.sh`): no second hearth
component in one app, and no two tracked paths that differ only by case. Proved able to fail — with the
old twin staged it printed `"apps/sessrumnir","TWO HEARTHS","2 implementations …"` and exited 1; with it
deleted it exits 0. Dead copies remain `dead-code-guard.sh`'s job, and that ward already names three in
bilskirnir, untouched here.

## Files

- `apps/sessrumnir/src/renderer/src/components/ember-background.tsx` (the one hearth)
- `apps/sessrumnir/src/renderer/src/components/home-screen.tsx` (the landing names its stacking context)
- `apps/sessrumnir/src/renderer/src/components/EmberBackground.tsx` (deleted — dead twin)
- `apps/sessrumnir/src/renderer/src/assets/ember.js`, `ember.d.ts` (deleted — dark copy)
- `apps/hlidskjalf/src/app/EmberBackground.tsx` (deleted — dead twin)
- `bin/desktop/sessrumnir-launch.sh` (tree + build, refusal, PATH for the app's spawns)
- `apps/sessrumnir/bin/sessrumnir.js` (`--remote-allow-origins` with the DevTools door)
- `bin/gates/guards/hearth-guard.sh`, `bin/gates/guards.sh`

## CHANGE LOG

- **2026-11-13** — written with the fix, from the running app's own measurements.

## Appended 2026-11-14 02:45 — the window that froze before it had done anything

The Allfather: *"Sessrúmnir starts over and over."* It was not a crash. Hyprland's "Application not
responding" dialog fired on a Sessrúmnir window at 02:28:00, 02:28:09, 02:33:46, 02:33:54 and 02:35:52,
and the window closed each time.

Measured with DevTools **detached** (so not the debugging session): for the first 60–90 s the main process
ran its JS thread at 100 %, three V8 worker GC threads at 100 %, reached 1.5 GB RSS and 43 s of CPU; then
it went idle and the window lived if the dialog's Wait was pressed.

A CPU profile of the main process (attached with `--inspect=9229`, 500 µs sampling) named the work rather
than guessing at it: `lstat` under chokidar's `_addToNodeFs`, and chokidar's own pattern matcher spending
its samples in `path.resolve`/`path.relative` through `isIgnoredPath`. It was the **first walk of the disk
watcher**, over a workspace that carries the house's 198 worktree checkouts in `.yggdrasil/`.

- `.yggdrasil` is now an ignored directory (a file tree never shows the worktree shelf).
- the first walk starts 2.5 s after a workspace becomes active, and is cancelled if the active workspace
  changes first, so the window answers the compositor in its first second.

Proof owed and taken: no not-responding dialog for five minutes, on both machines, from the pin.

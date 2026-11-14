# desktop · 2026-11-14 — on Omarchy no Ymir window shows minimize, maximize or close

## What was asked

The Allfather, 2026-11-14 (plan 275 item 34): *"on Omarchy none of the _ □ × buttons should be visible in any app."*
Hyprland — Omarchy's session — draws no title bar of its own and closes a window with a key
(`SUPER+Q`), so a drawn `_ □ ×` is dead weight there. Everywhere else the platform keeps its
frame.

## What was measured first

Measured on this machine (Omarchy, Hyprland, Wayland, scale 1.25), from the pin `4f5f6b13`, by raising
each app in a throwaway profile and photographing the real compositor surface:

| App | Frame before this change | What the operator saw |
|---|---|---|
| Hlidskjalf, Óðrerir | Electron frame on, menu bar built and shown | an `Ymir · View` menu row at the top — **no** `_ □ ×`, because Hyprland negotiates no decorations |
| Smíðja (raised through Hlidskjalf's shell) | same | the same menu row, no `_ □ ×` |
| Smíðja's own shell (`apps/smidja-factory/apps/visualizer/desktop/main.js`) | already frameless | it **draws** `_ □ ×` itself from `App.vue`, gated on `smidjaDesktop.platform === 'linux'` |
| Bilskirnir, Rödd, Sessrúmnir | Electron frame on, bar hidden | no `_ □ ×` today, but nothing stopped one appearing |

So today no Electron window actually shows the buttons on Hyprland — the compositor is what
decides. That is a fact of this compositor and this Electron build, not a guarantee: a GTK
client-side-decoration path, a different `--ozone-platform`, or an Electron that asks harder for
decorations brings them back. This change makes it a law rather than an accident, and removes the
one place that genuinely draws them (Smíðja's own shell).

## The change, in one line

The frame's buttons became a **platform capability** (`bin/host/host-sense.sh capability
window-buttons`) that every launcher asks once and carries into the app as
`YMIR_WINDOW_BUTTONS=on|off`; a frameless window where the answer is `off`, the platform's own
frame where it is `on`.

## Files

- `bin/host/host-sense.sh` — the new capability `window-buttons`, in the `capability` door, the
  TOON report and the help. It answers **no** on a tiling compositor (`hyprland`, `sway`, `niri`,
  `river` — Hyprland is Omarchy's), **yes** everywhere else. One predicate, in the one sensor the
  platform layer already owns (Rule 05).
- `bin/desktop/app-lib.sh` — `app_window_buttons`, the one function that turns that answer into
  `on|off` for the launchers. A launcher that cannot reach the sensor answers `on`: the platform
  default, never a silent change on a host nobody named.
- `scripts/electron.sh`, `apps/bilskirnir/start.sh`, `apps/rodd/start.sh`,
  `bin/desktop/sessrumnir-launch.sh` — each exports `YMIR_WINDOW_BUTTONS` to the shell it raises.
- `apps/hlidskjalf/electron/main.cjs`, `apps/odrerir/electron/main.cjs`,
  `apps/bilskirnir/electron/main.js`, `apps/rodd/src/main.js` (both windows),
  `apps/sessrumnir/src/main/index.ts` — `frame: WINDOW_BUTTONS`. The application menu is still set
  in every one of them, so the accelerators (`CmdOrCtrl+1..3`, reload, zoom, quit) remain the
  keyboard road in; only the drawn bar goes with the frame.
- `apps/smidja-factory/apps/visualizer/desktop/main.js` and `desktop/preload.js` — the shell
  answers one IPC question (`ymir:window-buttons`) and hands the renderer
  `smidjaDesktop.windowButtons`.
- `apps/smidja-factory/apps/visualizer/src/App.vue` — the topbar's `.win-controls` span now hangs
  on `showsWindowControls` (Linux **and** the platform's yes). Its drag region stays: a framed
  window keeps its bar, and a floating window on a tiling session can still be dragged.
- `.agents/tests/window-buttons.test.sh` (new) — holds the shape of the gate: the sensor answers
  in its own vocabulary, every `BrowserWindow` in `apps/` carries a frame decision, every window
  launcher asks, the application menus are still set, and Smíðja's topbar is gated.

## Proof, in the real windows

Every app was raised from this worktree in a throwaway `--user-data-dir`, its DevTools door on the
port the fleet assigns (`YMIR_DEVTOOLS_PORT`), taken fullscreen so it stood alone on the glass, and
photographed with `grim` on the compositor surface. Then its page was asked, through that same
DevTools door, what it draws.

| App | Window (grim) | Page, through DevTools | Verdict |
|---|---|---|---|
| Hlidskjalf :9311 | fullscreen, the app's own header at the top, no frame, no menu row | `winBtns: 0` | no `_ □ ×` |
| Óðrerir :9312 | fullscreen, `ᛟ YMIR · ÓÐRERIR — THE LIVE HALL` header, no frame | `winBtns: 0` | no `_ □ ×` |
| Smíðja :9313 (launcher's road) | fullscreen, crumbs + `ᛟ TO THE HALL` + theme, no frame | only the `Open Hlidskjalf` button carries `.win-btn` | no `_ □ ×` |
| Smíðja's own shell :9313, against this worktree's Vite on :8985 | frameless (it always was) | `bridge.buttons:false`, `controlSpan:false`, `controlButtons:0`, `minMaxCloseAnywhere:0` | the drawn `_ □ ×` are gone |
| Bilskirnir :9314 | fullscreen, its "The hall is silent" face, no frame | `winBtns: 0` | no `_ □ ×` |
| Rödd :9315 | fullscreen, `Rödd · the voice of Ymir`, no frame | 5 matches, all in-app dialog closes (`chat-panel-close`, `about-close`, `tools-close`, `limit-close`) — **no window control** | no `_ □ ×` |
| Sessrúmnir :9316 | fullscreen, its home screen, no frame | `winBtns: 0` | no `_ □ ×` |

The other direction, so the gate is proved and not a removal: Hlidskjalf raised with
`YMIR_WINDOW_BUTTONS=on` is **framed** — the platform's `Ymir · View` menu row returns — and
Smíðja's own shell with `on` draws its three controls again (`controlSpan:true`,
`labels:["Minimize","Maximize","Close"]`).

Bilskirnir was proved on its "the hall is silent" face: raising its hall would start Hermes and a
gateway for a frame test. Rödd's window was raised from its own shell, which spawns its Python UI
server on an ephemeral port; the voice pipeline was never started.

`.agents/tests/window-buttons.test.sh`: 23/23 ok. `apps/sessrumnir` builds (`npm run build`,
16.96 s). `node --check` on all five edited Electron mains and `bash -n` on all four launchers.

## What this does not do, and what is owed

- **Nothing was removed beyond the buttons.** Every menu, accelerator, in-app control (panels'
  own maximize/restore, dialog closes, the "Open Hlidskjalf" speed-start) and every drag region
  stays. Sessrúmnir's `windowControls` IPC — which raises the window when a workspace reports
  activity, and its notification-click path — is untouched: it was never a minimize/maximize
  button.
- **Owed: a second machine.** The other machine was unreachable from this pane while the work was
  done, so the release-fresh proof there has not been made. The gate is host-read, so the answer
  follows the host; it still has to be seen on that machine.
- **Not touched, by design:** `one-hlidskjalf` / `hall-follow` own Hlidskjalf's and Óðrerir's
  visible menu bar (plan 275 item 14) — with a frameless window on Omarchy that bar is no longer
  drawn, which is the same outcome by another road; the two changes agree rather than collide.
  Smíðja's header layout belongs to `smidja-header-chat`; this change touches only its
  `.win-controls` gate.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #754

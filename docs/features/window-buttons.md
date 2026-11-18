# Window buttons on a tiling desktop

On Omarchy no Ymir app shows minimize, maximize or close buttons — drawn or native. Hyprland tiles
windows and closes them with a key, so the buttons are dead weight there; on every other platform
the window keeps its own frame and its own buttons.

## What it is

Your Omarchy session is Hyprland, a tiling compositor: windows are placed by the layout, moved with
`SUPER` and the mouse, and closed with `SUPER+Q`. It draws no title bar of its own, so a `_ □ ×` in
a corner is a control with nothing behind it.

Every Ymir window therefore asks one question before it is drawn — *does this platform want window
buttons?* — and the answer comes from the machine, not from a setting you have to remember:

| Where you are | What a Ymir window looks like |
|---|---|
| Omarchy (Hyprland), or another tiling session (Sway, Niri, River) | frameless: no `_ □ ×`, no title bar, no menu strip |
| GNOME, KDE, XFCE, macOS, Windows | the platform's own frame, with its own buttons |

## What you need

Nothing. There is no setting: the platform layer reads the session and answers.

## What stays

- **Every keyboard shortcut.** The application menu is still built and still set, so `Ctrl+1`,
  `Ctrl+2`, `Ctrl+R`, the zoom keys and quit all keep working — only the drawn bar goes.
- **Every in-app control**: a panel's own maximize, a dialog's close, Sessrúmnir's workspace tabs,
  Smíðja's theme switch, the "Open Hlidskjalf" button.
- **The drag region** on an app's own header (Smíðja's), so a floating window can still be dragged.

## The commands

You do not need one. To see what the machine answered:

```sh
bin/host/host-sense.sh capability window-buttons   # yes | no
bin/host/host-sense.sh                             # the same fact, in the host report
```

## Limits

- The gate is the **session**, not the distro name: a Hyprland session on any distribution answers
  `no`, and a GNOME session on an Omarchy machine would answer `yes`.
- An app started by hand (`electron apps/hlidskjalf` from a terminal) has asked no launcher, so it
  takes the platform's default frame. Use `ymir-app <app>` — every desktop icon does.
- The frame is chosen when the window opens; a session switch needs the app restarted.

## If it does not work

If a window still shows `_ □ ×` on Omarchy, the app was started outside its launcher. Start it with
`ymir-app <app>`, and check the answer with the command above. If the answer is right and the
buttons are still there, that is a fault worth a fix note: the window is not reading
`YMIR_WINDOW_BUTTONS`.

## CHANGE LOG

- **2026-11-14** — Created with the change it describes (plan 275 item 34, branch `eindri/no-window-buttons`): the
  frame's buttons became the platform layer's answer (`bin/host/host-sense.sh capability window-buttons`), carried to
  every app as `YMIR_WINDOW_BUTTONS`, with the menus, shortcuts and in-app controls untouched.

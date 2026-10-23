# The halls, and the buttons that raise them

Ymir's four apps are **halls**, and each one has a button: an entry in your desktop's menu
and a key on your keyboard. This page is about those buttons — what they are, how to
renew them when they go dead, and what to say when one does nothing.

## What it is

Four launchers, installed into your own user's desktop:

| Hall | What it is | Key | Menu entry |
|---|---|---|---|
| **Hlidskjalf** | the control plane — the operator's high seat | `SUPER + Y` | *Ymir · Hlidskjalf* |
| **Smíðja** | the smithy — the agent factory and its visualizer | `SUPER + M` | *Ymir · Smíðja* |
| **Sessrúmnir** | the desktop seat — conversation over Pi and OMP | `SUPER + B` | *Ymir · Sessrúmnir* |
| **Óðrerir** | the hall of boards | `SUPER + O` | *Ymir · Óðrerir* |

On Omarchy each hall opens on **its own numbered desktop**, preferring an empty one, so the
four do not stack on top of each other. The placement is written by the same command as the
buttons.

## What you need

- A Linux desktop. The **menu entries** are the freedesktop standard, so GNOME, KDE and
  Hyprland all read them. The **keys** and the desktop placement are Hyprland's (Omarchy's).
- A Ymir install that still exists: either the npm package (`@zerwiz/ymir`) or a checkout.
  The buttons record an absolute path to it — that is the one thing they can break on.
- Nothing else. No daemon, no service: a click starts the app directly.

## The commands

```sh
bin/desktop/desktop-place.sh plan      # which desktop each hall would take, and why
bin/desktop/desktop-place.sh apply     # write the buttons, the keys and the placement, then reload
bin/desktop/desktop-place.sh status    # the path each button runs, and whether it still exists
bin/desktop/desktop-verify.sh          # every hall's runtime resolves, and every class is routed right
```

Everyday use is just the button or the key. `apply` is what you run after moving or
reinstalling Ymir, and `status` is what you run when a hall will not come up.

## Limits

- **The buttons name an absolute path.** If you move, delete, or reinstall the checkout or
  the npm package, the old path dies and the button goes quiet. `status` names it; `apply`
  re-points it.
- **A temporary path is never baked.** The generator refuses anything under `/tmp`,
  `/var/tmp` or `$TMPDIR` — if a run of Ymir is happening from a temp install, the buttons
  are left alone rather than pointed at something that will vanish.
- **The menu may need a moment.** After `apply`, the desktop database is refreshed and the
  Omarchy menu re-parsed; a menu already open may show the old list until it is reopened.
- **Nothing here installs the apps.** The halls must already be buildable on the machine;
  `desktop-verify.sh` proves they are.

## If it does not work

1. `bin/desktop/desktop-place.sh status` — does it print `"present"` for every launcher?
   A `"MISSING — this button is dead"` row names the path that vanished.
2. `bin/desktop/desktop-verify.sh` — does every hall resolve a runnable Electron? A `FAIL`
   names the surface and the path it resolved.
3. Still nothing, and the menu entry looks right by hand? Try the same door the menu uses:

   ```sh
   gtk-launch ymir-hlidskjalf
   ```

   If that opens the hall, the button is sound and the menu's cache is stale — reopen the
   menu. If it prints an error, the error is the answer.
4. If `apply` says **"no durable root raises the halls"**, neither the checkout nor the npm
   package carries the files the entries name. Point it at one that does:

   ```sh
   YMIR_LAUNCHER_ROOT=/path/to/a/complete/ymir bin/desktop/desktop-place.sh apply
   ```

# One extension home — a seat started by hand loads every door once

## What it is

When you type `pi` in a Ymir checkout, the harness loads its tools (the `ymir_*` doors,
the well, the seat, the ledger) from two places: the `.pi/extensions` folder of the folder
you are standing in, and whatever folder your Pi settings name as the extension home. If
those are two different checkouts of the same repository, every tool arrives twice and Pi
refuses to load all of them.

`bin/seat/pi-door.sh` is the door that stops that. It reads the situation before the
harness starts and picks one home:

- a launch that already names its extensions is handed through untouched;
- a folder with no `.pi/extensions` of its own is handed through untouched;
- a settings home that is the *same* folder is handed through untouched (Pi settles that
  itself);
- a settings home naming a *different* checkout is opened with discovery off, that folder's
  own extensions named once, and the packages your settings declare carried explicitly.

On install and on every update, `bin/seat/harness-extensions-install.sh` copies the door to
`~/.pi/agent/bin/pi`, which is first on your `PATH`.

## What you need

- Pi installed (`pi` on your `PATH` behind the door).
- `python3` (the door reads your settings file with it).

## Do it

Just start the harness. To see the decision it would make where you stand:

```bash
bin/seat/pi-door.sh --why
```

To watch it work:

```bash
PI_DOOR_VERBOSE=1 pi
```

To re-seat the door after it has changed:

```bash
bin/seat/harness-extensions-install.sh
```

To check it is current:

```bash
bin/seat/harness-extensions-install.sh --check
```

## Limits

- The door is a **copy** at `~/.pi/agent/bin/pi`, never a symlink into a checkout: a symlink
  would vanish the moment that branch is switched. A changed door is reported `stale` until
  the installer re-seats it.
- It never changes a launch that already names extensions (`-ne` or `-e`), so a worker
  started by the dispatcher keeps its own shape.
- Sessions outside any checkout are untouched: they keep the extension home your Pi settings
  name.
- `pi` called with its own installed path directly (`/…/cli.js`) skips the door.

## If it does not work

`bin/seat/pi-door.sh --why` prints the verdict, the home it would use and the reason. If it
says `pass`, the collision is not there and the door is standing aside on purpose.

If the door is missing, `bin/seat/harness-extensions-install.sh --check` says so, and
`bin/seat/valknut-load.sh --check` fails the extension-home line until it is seated.

## CHANGE LOG

- **2026-11-11** — written with the change (one extension home for a hand-started pi).

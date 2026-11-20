## install · unversioned · 2026-10-17 — migration 0008: an old home is healed into the layout

### What

Rule 21 says the home has a layout and nothing is created outside it. A **fresh install** gets
that shape; a home made before the rule existed does not — and every other user's home is such a
home. This is the migration that carries the shape to them, on the ordinary road (run by
`bin/engine/ymir-migrate.sh`, and therefore by Gróa on update and by the installer).

```
0008-home-layout — what it heals (each measured on a real operator home, 2026-10-13):
  state OUTSIDE the home          ~/Documents/Ymir/state, ~/…bak-scaffold/state   -> $YMIR_HOME/state/
  state INSIDE the repo           .agents/state, bin/state                       -> $YMIR_HOME/state/
  a stray hoard                   ~/hodd                                          -> folded into the real one
  companies under identity        hodd/identity/companies/<c>/                    -> svartalfaheim/<c>/
  a company's material in the
  operator's own shelf            hodd/life/{work,marketing,meetings}             -> the company's inbox
  a layout map naming ANOTHER
  MACHINE                         .ymir-layout.yaml                               -> regenerated here
```

**Platform-aware (Rule 05).** `ymir_os` now reports **`android`** — Android/Termux says
"Linux" but has no `Documents/` and no `USER`, and its home is short (`~/ymir-home`). The
migration therefore asks the platform before it looks: on a phone it folds in a
desktop-shaped home if one exists and skips the desktop strays entirely; on a desktop it does
the reverse. Detected by `uname -o`, `TERMUX_VERSION`, or a Termux `PREFIX` — any one suffices.

**The law it obeys:** nothing is deleted (a file is MOVED and the destination recorded);
nothing is clobbered (a name already at the destination is kept beside it and reported); every
branch is guarded by existence, so a home that never saw these paths pays nothing — **a no-op on
a fresh install**.

**What it will not guess:** whether a directory filed as a company was really a **product** of
one (only a person can tell), and which company or project a stray document belongs to. It moves
what it can, leaves the rest in a clearly-named inbox **inside the right company** — never under
`hodd/identity/` — and prints the list.

### Verified

- On a fake home carrying every fault: **5 moved, 3 left for a person**, and the tree afterwards
  held no company under `identity/` and no company material under `life/`.
- **Idempotent**: a second run reports **0 moved, 0 left**.
- `ymir_os` → `linux` here, `android` with `TERMUX_VERSION` set and with a Termux `PREFIX`.

### Files

- `.agents/migrations/0008-home-layout.sh`
- `bin/fleet/ymir-platform.sh` (Android detection)

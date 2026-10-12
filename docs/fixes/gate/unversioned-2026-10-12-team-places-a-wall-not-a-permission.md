## gate · unversioned · 2026-10-12 — team places: a wall, not a permission

### What

The Allfather: *"they should NOT see outside the team chosen places. never our private
files or so. we need to create team 'places'."* That is a stronger model than permissions:
a teammate is a **member of places**, and outside them **there is nothing** — not a private
file, not a plan, not a listing.

`bin/place/place.sh` builds the places and **proves the wall**:

```
place.sh create <name> [--member <id>]… [--owner <id>]   mint a place (its own roots)
place.sh list                                            the operator's view
place.sh show|members <name>                             who belongs
place.sh check [<name>]                                  PROVE no path leaves its place
```

A place **is a realm** (`svartalfaheim/<name>/`), so it inherits the realm boundary law
already in force. Its storage, room, board and record are **its own roots** — never a path
into the hoard.

### Verified — including the refusal, which is the feature

- Created `wayofteams` with two members; `list` shows it (operator view only).
- `check` → `escapes=0` · *"the wall holds — no path leaves its place"*.
- **The negative test**: a symlink planted at `files/private-peek → $YMIR_HOME/hodd/identity`
  was **caught** — `escapes=1`, *"ESCAPES FOUND — a member could see outside"*, exit **1**.
  Removed, and `check` returned to clean. That is the evidence the wall is a wall.

### Files

- `bin/place/place.sh`

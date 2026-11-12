# Bilskirnir keeps its hall in one home, not in a checkout

**2026-11-12 · component: apps · `apps/bilskirnir/scripts/data-home.sh` · `start.sh` · `setup.sh` · plan 275 S5**

## What was wrong

The hall kept its database, agents, engines, desk and `.env` under `apps/bilskirnir/` of whichever checkout ran it.
When the launcher moved to the pinned runtime, the icon opened a second, empty hall: the operator's agents and
conversations were still in the working tree's copy.

## What was done

`scripts/data-home.sh` links `data/` and `.env` to one home per user — `BILSKIRNIR_DATA_HOME`, else
`${XDG_DATA_HOME:-~/.local/share}/ymir/bilskirnir`. The first checkout to run moves its state there. A later checkout
that has its own copy sets it aside as `<name>.local-<stamp>`, so nothing is deleted. `start.sh` and `setup.sh` run it
first. `.gitignore` ignores the links and the set-aside copies.

## Proof

`apps/bilskirnir/tests/data-home.sh` — 8 of 8: the first checkout donates its hall, a second checkout opens the same
hall and keeps its own copy aside, `--check` changes nothing, and a second run is a no-op.

## Owed on a machine that already has two halls

Run the door first in the checkout whose hall is the real one, while its server is stopped, so that hall becomes the
home. Then any other checkout links to it.

## CHANGE LOG

- **2026-11-12** — the hall's state moves to one home per user.

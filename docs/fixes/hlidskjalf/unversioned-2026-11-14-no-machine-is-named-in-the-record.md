## hlidskjalf · unversioned · 2026-11-14 — no machine is named in the record

### Why

The helm's audit of `eindri/fleet-truth-2` found one line in the Fleet-page fix note that named a
**remote machine** — the one the second-machine proof could not reach. A hostname in this public
repository tells a reader about a machine the house has that is not this seat (RULES/39: never give
out the address, and never write it down where the repo can be read).

### What changed

That line now reads, in the helm's own words:

> **Not proved:** a second machine. The second machine's ssh road timed out at 04:10, and the
> release-flip pass needs the merge this branch does not perform.

The fault and its consequence are unchanged; only the name is gone. The correction is made in
place rather than appended, because an appended correction would leave the leak standing in the
record it corrects.

### Files

`docs/fixes/hlidskjalf/unversioned-2026-11-14-the-fleet-page-told-the-truth.md`.

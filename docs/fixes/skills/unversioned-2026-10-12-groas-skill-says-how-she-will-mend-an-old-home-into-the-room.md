## skills · unversioned · 2026-10-12 — Gróa's skill says how she will mend an old home into the room

### What

The room is **planned, not shipped** (2026-10-12). When it lands, an existing home must heal
forward into it **without a hand on the box** — which is Gróa's job. Her skill now says so:
the new piece is `.agents/migrations/0008-room` (versioned, idempotent), followed by
`bin/fleet/fleet-ensure.sh ensure`, followed by a report that names the room's state.

The two rules it records, so the eventual migration does not break the fleet: it must be
**idempotent** (re-running changes nothing) and **role-aware** (the engine on the heart, the
client on the seats) — a seat running the migration must never raise a second homeserver.

### Verified

- The note is marked **planned, not shipped**; it adds no step Gróa does not yet run.
- It cites plan 75 Part 9 (the shipping law) and Part 11 (the fleet shape), and ticket
  ymir/57, so skill and ledger agree.

### Files

- `.agents/skills/groa-update/SKILL.md`

### The requirement stated plainly (the Allfather, 2026-10-12)

> *"ymir updates and installations must have fleet and single machine logics"*

So the asset now names **both shapes** and the split plainly: a **single machine** seats
engine + client on itself; a **fleet** seats the **engine role once, on the heart**, and
every other seat seats the **client role only**. The install/update **detects** the shape
(the fleet already declares its role) and never assumes — a seat that runs it must not
raise a second homeserver, and a machine the change does not apply to must **skip cleanly**,
not fail.

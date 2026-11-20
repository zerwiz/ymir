## install · unversioned · 2026-10-12 — Gladsheim is SEATED: the door, the role-aware ensure, the install step, the migration

### What

The room's engine was proven by hand; nothing *shipped*. This makes it shipped — the
plumbing that turns "works when I put my hand on the box" into "works on install and
update", and it is **role-aware by construction**, because a fleet and a single machine are
not the same install.

| piece | what it is |
|---|---|
| `bin/room/gladsheim.sh` | **the door**: `status · send · read · who` — an agent speaks from the shell. Resolves homeserver / server name / room / **this machine's agent name** from the hoard (Rule 07); the token is a secret **by reference** (Rule 04). |
| `bin/room/gladsheim-ensure.sh` | **the role-aware ensure**: asks `bin/fleet/topology.sh` for the shape, seats the engine **once** (a lone box, or the **heart**), and **skips cleanly** on every other seat — a seat never raises a second homeserver. |
| `bin/engine/ymir-install.sh` | a **`step_room`** in the install's own plan, beside `the A2A mesh` |
| `.agents/migrations/0008-room.sh` | the **update**: heals an existing home forward, idempotent, and seeds a client config if none exists |

**The bootstrap token is PINNED, not scraped.** The live proof (2026-10-12) found the
generated registration token **changes across restarts**, so an installer reading it from a
log is racing the server; the ensure writes `registration_token` into the engine config
before first boot.

### Verified

- `bash -n` clean on all three scripts.
- The door **spoke**: `send` returned an event id, and `read` returned the message — a real
  round-trip against a live continuwuity on `:8008`.
- **The shape law holds, measured on this seat**: `status` reports `shape=fleet`,
  `holds_engine=no`; `ensure` prints *"this seat is a client — the engine belongs to the
  heart (zerwizserver); skipping cleanly"*; forcing the heart role seats the engine
  (`engine up`, pinned token written).
- `0008-room.sh` runs against this home and skips cleanly, leaving the existing config
  untouched; the installer lists `step_room "the room"`.

### Files

- `bin/room/gladsheim.sh`, `bin/room/gladsheim-ensure.sh`
- `bin/engine/ymir-install.sh`
- `.agents/migrations/0008-room.sh`

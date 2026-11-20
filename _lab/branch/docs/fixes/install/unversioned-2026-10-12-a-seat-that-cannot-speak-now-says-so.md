## install · unversioned · 2026-10-12 — a seat that cannot speak now says so

### What

The seat path of `gladsheim-ensure.sh` was a shrug: it printed *"client (seat) — skipping
cleanly"* and exited, whether or not the seat could actually reach the room. That is the bad
kind of clean skip — it reports success for a door that may be locked.

It is now a **real door-check**: on a client seat it reads the seat's `config/room.yaml`
(its own agent name, the homeserver, the room), checks the token is present, probes the
homeserver, and reports **what is missing** — exiting non-zero when the seat cannot speak.

Two defects found while making it work, both by running it:

1. `local` was used in the `case` arms — legal only inside a function, so the script failed
   with *"local: can only be used in a function"*. Stripped.
2. A hand-rolled YAML reader set `doc['agents']` to a string on the `agents:` line and then
   assigned into it — `TypeError: 'str' object does not support item assignment`. Fixed to
   allocate the map on the key line.

### Verified

- This seat: `role=client` · `agent=Brokk` · `homeserver=http://zerwizserver…:8008` ·
  `reachable=up` · `token=yes` · `missing=nothing — this seat can speak` · exit **0**.
- `bash -n` clean; the engine path (`status`) still reports shape/role/heart correctly.

### Files

- `bin/room/gladsheim-ensure.sh`

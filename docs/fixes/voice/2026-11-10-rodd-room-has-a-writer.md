## voice · 2026-11-10 — Rödd's room has a writer: `bin/voice/rodd-room.sh reply`

### What
New door for the arm holder's half of Rödd's room: `reply "<text>"` appends `{"ts","from","text"}` to the room the
arm lease names, refusing (exit 3) any session that does not hold the helm; `path` prints where the room is.

### Why
`rodd-arm.sh` says "the arm writes the room", but no code did: the first reply to Rödd (2026-11-10) was appended by
hand to the documented contract.

### Verified
`rodd-room.sh path` resolves `<home>/state/rodd/room.jsonl` from the lease; `rodd-arm.sh hear` reads lines in this
shape (proven with the hand-written reply).

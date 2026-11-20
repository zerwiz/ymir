## docs · 2026-10-21 — the front door names Garmr

### Why
Garmr appeared in the README only as a clause inside a list of engines — *"and Garmr the hound, with
the distinction that a ward refuses and the hound watches"*. A promise that specific deserves a
section, because the four things that make the hound safe are exactly the four things a reader would
otherwise assume wrongly.

### Fix
A section, **Garmr — the hound at the gate**, in his own terms and grounded in `bin/ward/garmr.sh`
and the guardian's config:

- **read-only against the machine** — he never closes a door, never kills a process, never edits a
  tree; a watchman who can act is a second hand on the wheel;
- **a fact never passes through a model** — the alarm is a template built from what was measured, and
  a reasoner is asked only to write the paragraph *beneath* the fact, never the fact;
- **the loop never calls a model** — the rail holds one model at a time, so the watch is
  deterministic and a model is something you ask for, not something a cron does;
- **silence is a finding** — a dead hound looks exactly like a hound that found nothing, so his own
  heartbeat is watched and a silent guardian is a CRITICAL, not a quiet night.

It closes with the division of labour the code already keeps: what he notices, Vörðr reports, Gná
carries, and Runes keeps — and none of them can open a door.

### Verified
`docs-claims-guard` → every claim resolves across 124 pages.

### Files
- `README.md`

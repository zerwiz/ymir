## docs · unversioned · 2026-10-12 — the team and gate features get their pages (Rule 14)

### What

Rule 14: a feature with no page is a feature no user can use. Five features were named or
built this day and had none — so they have pages, and `FEATURES.md` gains a **"Planned and
new"** section that links every one:

- `team-places.md` — a place is a wall, not a permission; outside it a member sees nothing;
  `place.sh check` proves it and refuses a planted escape.
- `distinct-gates.md` — Rule 18: one class per service, one gate per class; the refusal is
  the feature.
- `encryption-and-sensitive-data.md` — at rest, in transit, end to end; and the measured
  truth that an encrypted room is only encrypted if **every** client encrypts.
- `gladsheim-the-fleet-room.md` and `brimir-the-hall-of-allfathers.md` — carried over from
  the docs branch so **one** PR holds the whole catalogue.

The rows are honestly labelled: *planned*, *partly built*, or *law* — never claiming a
capability that does not exist.

### Verified

- Every row links a page that exists in `docs/features/`; no `| — |` blanks.
- `bash -n` unaffected; no code touched by this record.

### Files

- `FEATURES.md`
- `docs/features/team-places.md`
- `docs/features/distinct-gates.md`
- `docs/features/encryption-and-sensitive-data.md`
- `docs/features/gladsheim-the-fleet-room.md`
- `docs/features/brimir-the-hall-of-allfathers.md`

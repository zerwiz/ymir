## docs · 2026-10-21 — the front door names the rest of the hall

### Why
Measured against `FEATURES.md` (78 rows, 40 of them carrying a bold feature name), 26 were already
named in the README and 14 were not — and the 14 turned out to be **twelve** features, because
`FEATURES.md` lists Gladsheim and Brimir twice each. Nine of those twelve were invisible from the
front door, including the strongest promise the project makes (the confidential session) and the
reason the assistant treats people differently (the collaborator tiers).

### Fix
A section, **The rest of the hall**, as a twelve-row table: Gladsheim (the fleet room, and how it
differs from the rooms), Brimir (**marked PLANNED**), the meeting set (Trello board, sign-off by
email, first-run setup), the security pair (distinct gates; encryption and sensitive data), the
runtime pair (the notification door; approvals that can be answered), the confidential session, the
high seat's terminal, and collaborators and clients with their three tiers.

Two rules kept while writing it: **a planned thing says PLANNED** (a catalogue that cannot tell
built from intended is a wish list wearing a documentation's clothes), and no path is claimed in
the table, so the ward has nothing to reject that a rename could later break.

### Verified
`docs-claims-guard` → every claim resolves across 124 pages.

### Files
- `README.md`

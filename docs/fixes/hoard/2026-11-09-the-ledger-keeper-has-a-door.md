# hoard · 2026-11-09 · The ledger keeper has a door

## What

Plan 235's first half: the ledger's state becomes a field a machine can read. `Status:` and `Owner:` per plan
header, a door that reads and writes them, and the index woven from the files instead of hand-kept.

## Why

Measured 2026-11-09: 185 plan files, nine carrying a state, none carrying an owner, no `done/` shelf, and a
stale derived queue. A ledger in which "done" cannot be read is a ledger nobody can plan from — and an
ownerless plan is one that everyone assumes someone else is building.

## Proof

The door's own test and the audit tally are in the pull request; the sweep over the 185 files is the keeper's
in-hand work, committed to the home (see the PR body for the commit).

## Change log

- **2026-11-09** — written with the door.

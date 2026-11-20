# Team places — a wall, not a permission

> **Status: partly built.** `bin/place/place.sh` (create · list · show · members · check — the
> wall) ships; the tools inside a place are not yet scoped to it. This page is the contract.

## What it is

A **place** is where a team works. It has its own files, its own room, its own board, its own
record — and its own members.

The important part is what a place is **not**: it is not a folder with permissions. A teammate
is a **member of places**, and **outside their places there is nothing** — no files, no names,
no listings, no counts.

> *A member cannot name what they cannot see.* Not "access denied" — **absent**.

## What you need

- Ymir, with the places tree on the machine that holds your team's work — **a place is a
  server thing** (the always-on box), not a laptop.

## Do it

```bash
bin/place/place.sh create acme --owner you --member anna@example.com --member bo@example.com
bin/place/place.sh list                 # the operator's view: every place
bin/place/place.sh show acme            # one place: its members
bin/place/place.sh members acme         # who belongs
bin/place/place.sh check acme           # PROVE the wall
```

`check` is the guard: it walks a place's tree and fails if **any path leaves the place** — a
symlink into your private files is caught. That is the denial that proves the wall is a wall.

## Notes and limits

- **A place is a realm.** It lives under `svartalfaheim/<place>/` and inherits the realm
  boundary law: never touch another realm without explicit approval.
- **Its roots are its own.** A place never contains a path into the operator's hoard.
- **Private files never appear.** The place's member sees their place, and only their place.
- **Not yet:** scoping the *tools* (the room, the board, the files service) to the place, and
  membership by SSO. Those are plan 77 steps 77.1–77.5.

**See also:** [`distinct-gates.md`](distinct-gates.md) — the classes a place belongs to.

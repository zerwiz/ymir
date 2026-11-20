# Brimir — the hall of Allfathers

> **Status: planned — not yet built.** This page is the plain-language contract for a
> feature that has been named and designed (plan 74, ticket ymir/56) but does not run yet.
> When it lands, this banner is removed **by a new entry citing this one** (Rule 06).

## What it is

**Brimir** is a hall of the gods — and in Ymir it is **the hall where different operators
talk**. Where [Gladsheim](gladsheim-the-fleet-room.md) is *your* fleet's room, Brimir is
the room that **spans installs**: you, another Ymir owner, and **your Ymirs** — each in
the same conversation, each as itself.

It is a self‑hosted, federated chat — the shape of a self‑hosted Telegram, but with a
difference that matters: **no one owns the middle.** Each operator runs their **own**
homeserver, and rooms simply span them.

## What it is for

- A friend, a client, or a partner runs their own Ymir. You want to **talk** — and you
  want your agent to be able to **help** without either side handing over their data.
- So: **the operators talk in the room**; **their Ymirs delegate tasks to each other over
  A2A** (Ratatoskr), under an explicit, revocable, per‑skill **grant**. The answer comes
  back into the room.

## What you need

- Ymir installed, with Gladsheim's engine standing (Matrix — **continuwuity** + Element).
- **Federation** enabled, and a **grant** naming the peer — access is by **validated
  identity, never ambient trust**. A grant is per pair *and per skill*; a revoked friend
  is refused at once, and the refusal is recorded.

## Do it

```bash
bin/constellation.sh list                 # who is out there (the directory of installs)
bin/constellation.sh grant <peer> <skill> # what this peer may ask of us
bin/room/brimir.sh send "…"               # speak in the shared room
```

## Notes and limits

- **Nothing crosses that was not granted.** Not the hoard, not the well's memory index,
  not a calendar. The mesh carries **answers to questions** — and an answer is something
  the asked side *chose* to send.
- **One install, one operator.** Collaboration is **between** installs, never within one
  (plan 60/10).
- **Vault content never enters a federated room** (Rule 15) — and a **confidential
  session** has no route off the box at all (Rule 16).
- **It ships with Ymir**, exactly as Gladsheim does — install step, migration, a
  repo‑owned unit, Gróa and Eir surfaces (plan 75 Part 9).

**See also:** [`gladsheim-the-fleet-room.md`](gladsheim-the-fleet-room.md) ·
[`ratatoskr-a2a.md`](ratatoskr-a2a.md) — the task layer · plan 74 · plan 61 (the
constellation) · plan 75 (the build).

---
title: "A2A — the repository's card"
status: "accepted"
owner: "the project's collaboration-kit owner"
updated: "2026-11-11"
---

# A2A — the repository's card in the constellation

**What this is.** A repository that answers for its areas can also *say so* to a peer. `scripts/a2a.sh`
generates an A2A agent card (protocol `a2a/1.0`) from the same shelf the areas gate reads: **every held
area becomes a skill**, every unheld area is deliberately absent — you do not advertise work nobody holds.

```bash
bash scripts/a2a.sh card                                     # what it would say; writes nothing
bash scripts/a2a.sh card --url https://example.org/ --write   # publish the address that ANSWERS
bash scripts/a2a.sh check                                    # validate it
bash scripts/a2a.sh skills                                   # area · state · keeper
```

The card lands at `.well-known/agent-card.json`, which is where a peer looks.

## The five rules a card obeys

1. **Publish the address that answers, or publish none.** `127.0.0.1` dressed as a host is the failure
   the fleet paid for on 2026-11-05; `a2a.sh check` refuses a loopback `url`.
2. **A card is metadata, never a secret.** No token, no key, no mailbox. `check` refuses anything that
   looks like a credential or a person's address.
3. **A card does not name the house.** A repository that is not ours publishes its own name; our
   figures, ports, hosts and paths never travel (`RULES/48`).
4. **A card is an invitation to ask, never a grant.** A peer still needs a per-pair, per-skill grant
   with an expiry, and a recorded call. Advertising a skill grants nothing.
5. **The card follows the shelf.** Regenerate it when an area changes hands; `a2a-guard` refuses a push
   that changes the card into something invalid, and `a2a.sh check` reports an area held in `areas/`
   that the card does not offer.

## What a skill means here

A skill is one area, named `area-<id>`, with the canon's question as its description:

```json
{ "id": "area-tenancy", "name": "multi-tenancy and isolation",
  "description": "can one tenant read a row that belongs to another, by any route we expose?",
  "tags": ["area", "tenancy", "held"] }
```

So a peer that wants to know who holds tenancy asks the card, and a peer that wants the answer asks the
skill — with a grant. That is the whole of the A2A surface this kit carries: a truthful card and a
door that can refuse.

## Honest limit

This kit does **not** run a server. The card is a file; serving it is the repository's own business
(a static file behind its door, or the platform it already runs). The kit guarantees only what it can:
the card is generated from the record, it is valid, and it does not lie or leak.

## CHANGE LOG

- **2026-11-08** — Opened with the card: protocol, skills, the grant scheme, and the five rules a card obeys.

## References

- `scripts/a2a.sh`, `scripts/a2a.py`, `scripts/gates/a2a-guard.sh`, `docs/areas.md`
- `docs/headers.md` — the header and References format this document follows

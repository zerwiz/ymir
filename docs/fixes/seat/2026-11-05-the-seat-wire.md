# The seat wire — one seat speaks into another's live pane

**Component:** `bin/seat`, `hodd/identity/seats.yaml` (home) · **Date:** 2026-11-05 · **Plan:** 189

## What was wrong

Two live Pi seats on two machines, on one tailnet, could not read each other. The A2A doors bound loopback (fixed
separately, plan 188 §15/§16), and when a seat did speak — Hœnir typed straight into Sindri's pane, and Sindri answered
in **Telegram** — the far seat saw nothing, because a pane is not a chat. Every cross-seat word cost a git round trip.

## What this adds

`bin/seat/seat-wire.sh` — five verbs, no daemon, no token, no grant:

```
seats | who <seat> | read <seat> [--lines N] | say <seat> "<line>" | wait <seat> [--timeout MS]
```

- the peer's **pane is resolved live** from `herdr agent list` over ssh — never a stored id, never a guess;
- the peer's **identity is the far seat's own answer** (`~/.pi/agent/extensions/.ymir-seat`), so a registry that drifts
  is reported, not obeyed;
- every line is delivered with the attribution prefix `[seat <name> via the wire, <UTC>]`;
- every `say` writes the room line **first** (`hodd/rooms/<room>/<seat>.jsonl`) and speaks second, so a refused delivery
  still leaves the record;
- the registry lives in the private home (`hodd/identity/seats.yaml` → `machine: {host, ssh_user}`), so **no address is
  committed here** (Rule 39 · Rule 04).

## Refusals (named, loud, no fallback)

peer unreachable · no agent seated in that herdr · **two or more agents — listed, never guessed** · speaking to one's own
seat · text carrying control sequences or over 4000 characters.

## Verified

- `seat-wire.sh who heimdall` from nidavellir → `heimdall · Hœnir · w39:p5 · <session id>`.
- `seat-wire.sh say heimdall "…"` → `say[1]{to,pane,road,recorded}: "heimdall","w39:p5","pane","the-fleet"`, and the far
  seat reported the line arriving **intact with its attribution prefix**.
- `seat-wire.sh seats` resolves both seats to their tailnet addresses (`ssh heimdall@100.69.101.57`,
  `ssh zerwizomar@100.110.19.71`) with reachability `up`.

## Left open (plan 189)

The MCP door (`bin/mcp/ymir-mcp.py` → `seat_wire`) and the install step, so every harness gets it from one door rather
than a remembered shell line; and the `watch` verb that turns the gna arm into a fleet arm.

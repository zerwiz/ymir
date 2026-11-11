# The seat wire measured itself through a door that refuses no one but its own host

**Date:** 2026-11-11 · **Component:** `bin/seat/seat-wire.sh` (`seats`) · **Law:**
`RULES/25-agnostic-by-construction.md` (probe, never assume — and never a false red),
`RULES/06-append-only.md` (a correction is a new entry).

## What was seen

Proving the arm-to-arm road between seats on 2026-11-11, `bin/seat/seat-wire.sh seats`
printed:

```
seats[2]{seat,primary,reachable,door}:
  "heimdall","Hœnir","unreachable","ssh heimdall@100.69.101.57"
  "nidavellir","Hávi","up","ssh zerwizomar@100.110.19.71"
```

The seat that owns the table reported itself **unreachable**. Read cold it says the fleet
is half blind, which is the most expensive kind of wrong: a green that hides a break is
bad, and a RED that hides a working road is worse, because it sends the next hand looking
for a fault that does not exist.

## What was actually true

- `ssh heimdall@100.69.101.57 'echo hello'` → `Permission denied (publickey)`.
- from **nidavellir**: `ssh heimdall@100.69.101.57 'echo BACK-OK'` → `BACK-OK`, and the same
  by the tailnet name `heimdall.tailefab81.ts.net`.
- `~/.ssh/authorized_keys` on this box carries `omarchy-105`, `zerwizserver@wayofteams`,
  `whynot@whynot`, the GitHub signing keys and `u0_a749@localhost` — **not this host's own
  key**.

So the road works in both directions between the machines, and the only failing dial was
**heimdall dialling itself**. `cmd_seats` reached for every registry row over ssh, including
the row for the machine it was running on; this host's own public key is not in its own
`authorized_keys`, so the door that answers for every peer refused the machine itself.

## The mend

`cmd_seats` asks `self_seat` (the recorded seat, `host=` in
`~/.pi/agent/extensions/.ymir-seat`) and, when the row is this machine, measures it
**locally** — `up (self)`, door `local — this machine` — instead of over ssh. The wire does
not need a key to talk to itself, and a seat is never unreachable from inside itself.

```
seats[2]{seat,primary,reachable,door}:
  "heimdall","Hœnir","up (self)","local — this machine"
  "nidavellir","Hávi","up","ssh zerwizomar@100.110.19.71"
```

## The proof that the road is real, not merely reported

Two attributed lines crossed the arm-to-arm wire the same hour, and both survive in the
queues:

- **heimdall → nidavellir**, `bin/seat/seat-wire.sh nudge nidavellir "…"` → landed on
  `/home/zerwizomar/Documents/ymirhome/state/.wake-queue`, resolved from
  `/home/zerwizomar/Documents/ymirhome/state/.arm.lease`; nidavellir's helm is
  `pid=1182 starttime=1205 gen=29 mode=systemd session=5425`, held.
- **nidavellir → heimdall**, the same verb run on that seat by hand →
  `from=nidavellir to=heimdall at=2026-11-11T22:04:33Z` in this box's
  `/home/heimdall/Documents/ymirhome/state/.wake-queue`.

A one-way channel that reports "sent" is the false green this house has paid for before
(plan 188 §14-16). This one was proved in both directions before it was called mended.

## What this does not mend

- **This host's own key is still not in its own `authorized_keys`.** That is a separate,
  deliberate question: self-ssh is not needed by any door the house uses, and adding a key
  widens a ward for a road nothing walks. Left as it is, named here so the next hand does
  not read the local probe as a fix for self-ssh.
- **A seat's own row now answers without measuring the machine's services.** It says "this
  is the machine you are on", which is true by construction; every capability check still
  belongs to Eir (`bin/agents/eir-doctor.sh`) and to the doors that own each surface.

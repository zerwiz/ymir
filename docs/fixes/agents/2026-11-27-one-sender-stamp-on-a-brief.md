# One sender stamp on a brief

## What went wrong

A brief that already led with a stamp naming no road back got a second stamp from `herdr-run.sh`. The engine read a
leading `[reply from …]` line as the name of the sender. The feature page called the turn-end hook "tested" when its
test used fakes.

## What changed

- `herdr-run.sh` replaces a leading stamp that is not the resolved sender, so a brief carries one.
- `seat.py` takes a sender only from a `[from …]` stamp. A reply stamp stays in the brief, under the sender's own.
- The feature page says "tested with fakes".

## Proof

`bin/agents/tests/test_sender_direct.sh` holds one case for each of the two stamp rules: 47 ok, 0 failed.

## CHANGE LOG

- 2026-11-27 — a brief carries one sender stamp, and a reply stamp never names the sender.

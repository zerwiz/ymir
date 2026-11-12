# The hall finds every root, and waits for a busy one

**2026-11-12 · component: apps · `apps/bilskirnir/scripts/data-home.sh` · follows PR #704**

## What was wrong

PR #704 made the hall's state live in one home, chosen from the checkouts on the machine. Two cases were measured
wrong before the first real run:

- **The pin could not see the working tree.** The candidates were the checkout itself, the pin, and the main-tree
  resolver's answer — and from the pin that resolver answers the pin. A pin started first (the 04:10 update) would
  make a new, empty home while the operator's real hall stayed behind in the working tree.
- **A busy hall lost to a smaller one.** A hall whose server is running was skipped, so the next largest — an empty
  one — was chosen instead.

## What was done

- The candidates now include every root the machine records in `~/.pi/agent/extensions/.ymir-root` (the working tree
  and the pin both appear there).
- When the largest hall belongs to another checkout's running server, the door changes nothing and says it waited.
  The next start after that server stops makes the move.

## Proof

`apps/bilskirnir/tests/data-home.sh` — 16 of 16, fenced to its temp folder (HOME, the pin and the data home all point
inside it). New cases: from the pin, the root record finds the working tree's hall; a busy real hall makes the door
wait and moves nothing; once the server stops, the next start takes the real hall.

## CHANGE LOG

- **2026-11-12** — every root is a candidate, and a busy real hall is waited for, never replaced.

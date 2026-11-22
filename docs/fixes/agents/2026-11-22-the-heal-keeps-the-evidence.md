# A healed report keeps its evidence and its record

**Date:** 2026-11-22 · **Component:** agents (`bin/agents/eindri-acclaim.sh`) · **Plan:** 350 part B

## What was wrong

While a worker waits a long time on a command, the liveness sweep may file a guess on its report shelf: *"finished
without a terminal word"*. When the worker's own done act came later, two things happened in order:

1. The act appended its `## Evidence` and `## Record` blocks to the guess.
2. The correction step then rewrote the whole shelf to the bare status line.

The proof was erased. It was measured on this plan's own terminal act: five green evidence commands, and a shelf
of one line.

## What was built

The correction replaces the sweep's guess with the worker's word and **keeps** the Evidence and Record blocks the
act wrote.

## Proof

`bash bin/agents/tests/test_acclaim_evidence.sh` — 16 passed, including "the evidence and the record survive the
heal". `bash bin/seat/tests/test_everything_up.sh` — 30 passed.

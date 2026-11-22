# Behaviour contracts: every system does the real thing, checked on the clock

**Date:** 2026-11-22 · **Component:** ward (`bin/ward/contracts.sh`, `bin/ward/contracts.d/`) · **Plan:** 350 part F

## What was wrong

Eir asks whether a thing is installed and up. Nothing asked whether it **behaves**. On 2026-11-22 three systems
were "up" and still failing:

- The nightly renewal timer failed on all three machines.
- A house unit (`housewatch.service`) sat `failed` on a second machine.
- The review watcher handed the same head to review again and again.

## What was built

- `bin/ward/contracts.sh` runs every contract in `bin/ward/contracts.d/`. A contract does the real thing,
  read-only, and prints one line: `ok:`, `red:` or `skip:`. One that runs out of time is red, named as hung.
- `contracts.sh check --notify` keeps the reading in `state/contracts/<host>.json`. A contract's turn to red goes to
  the arm holder through the Veil, with a receipt, and a red that stays red is not said twice.
- **The board.** The trouble panel gains a `contracts` row. Its fleet view shows every machine's reds. When the
  operator chooses Gatus (the research note in the home weighs it against Healthchecks), `GATUS_URL` and
  `GATUS_TOKEN` push every result to its external endpoints, so there is one board and no second dashboard.
- **The first five contracts:**
  1. The nightly renewal ran and did not fail.
  2. No user unit sits `failed`.
  3. One head is handed to review at most twice in a day.
  4. Every Veil report is RECEIVED within ten minutes.
  5. A recall from the well returns episodes.
- The cron template runs `contracts.sh check --notify` every 15 minutes on each machine.

## Proof

- `bash bin/ward/tests/test_contracts.sh` — 10 passed. This includes a head handed to review four times, which is
  red.
- `bash bin/ward/tests/test_trouble.sh` and `test_trouble_veil.sh` — still pass.
- On the dev machine, the contracts named Gróa's failed unit twice (as the nightly contract and as a failed unit)
  and two reports past their receipt line. The well answered.

## CHANGE LOG

- 2026-11-22 — review-mend: added missing heading for #895

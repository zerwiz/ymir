# The seat probes the server, and a machine with no live primary may give it the helm

**Date:** 2026-11-06 · **Plan:** 206 §6 M3 · **Law:** `RULES/25-agnostic-by-construction.md`, `RULES/13`

## What was wrong, measured on the heart

Two faults, both found by running the loop where it is meant to live.

1. **The seat refused on a variable.** `herdr_ok` demanded `HERDR_ENV=1`, so the seat refused from a
   timer and over ssh **while the herdr server stood and answered**. A probe that reads a variable
   instead of asking the machine is the same fault the house has paid for twice (RULES/25).
2. **The heart has no live primary.** Its `brokk.lock` named pid `547578`, which was dead, so every
   `lock-ask ask` was refused — correctly — and the loop could raise nothing at all. The refusal was
   the door being honest; the machine was the fault.

## What changed

- `need_herdr` probes the **server** (`herdr agent list` answers) and names which of the two faults it
  found: herdr absent, or the server not answering.
- `review-seat.sh ensure --primary` gives the review seat the helm **only when no live process holds the
  lock**, and refuses when one does. A machine with no primary has nobody to drain the arm; a machine
  with one keeps its seat a seat.

## Verified

On `zerwizserver`: `herdr agent list` answers, `review-seat.sh status` reports the clone and no seat,
and `lock-ask ask` refused with `the lock names pid '547578', which is not a live process` — the exact
sentence that sent this change.

## CHANGE LOG

- **2026-11-06** — written after the heart's own refusals named both faults.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the fleet's always-on heart. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

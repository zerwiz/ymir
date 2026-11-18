# The census is enabled per machine, so the sweep ships commented out

**Plan:** 290 (with 275 / 287). **Date:** 2026-11-14.

## What was wrong with the last commit

Seating the private sweep in the cron template made it `@heart`-scoped and **active**. Two faults
follow from that, both at odds with plan 290 (the operator's word: every clock is per machine):

- a fleet of one has no `@heart` at all, so the row would silently never run;
- a fleet of twenty would sweep one tree twenty times and queue the same finding twenty times.

A shipped default is not a decision. The census belongs to the machine that owns it.

## The fix

Both templates now carry the two rows **commented out**, under one line that says so plainly:
*enable on the machine that owns the census*. The note above them keeps the division of labour —
the clock queues and seats one triage errand, the gate refuses the change — and says why the row
is shipped off. The Galdr asset records the same thing, so the book and the template agree.

## How it was proved

- `bin/gates/guards/cron-guard.sh` passes: a commented row is not a row.
- The templates' live rows are unchanged; the sweep is now an act on the machine that holds the
  census, and this fleet's own home keeps running it.

## CHANGE LOG

- **2026-11-14** — written with the change it describes.

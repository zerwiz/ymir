# The gate proves a change once

**Date:** 2026-11-09 · **Component:** gate · **Door:** `AGENTS.md` (the delivery gate section)

## What was wrong

Nothing was broken; a law was missing. Every repair to an already-approved pull request was being
held until the whole CI suite proved it again — a five-minute run to re-prove work that had already
been proven, for a one-line fix note or a stale register. Twice in one night that cost the operator
a merge he had already sealed.

## What was forged

A dated section at the end of `AGENTS.md` (Rule 06: the contract is appended to, never rewritten):
the gates judge a PR **when it is first offered**, and a repair of that PR does not re-earn the
suite. The pre-push wards still run (they judge the tree, and they are cheap); the fix note and the
test are still owed (the record is not the gate). A repair that changes behaviour beyond the fix is
new work and earns its own proof.

## Verified

`AGENTS.md` parses as before (it is prose); the section is dated and appended, nothing above it
moved.

## CHANGE LOG

- **2026-11-09** — the law was appended at the Allfather word (PR #612 made main green; this one makes the rule plain).

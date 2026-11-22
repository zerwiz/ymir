# The Veil's ledger follows the arm, never a worker's seat state

**Date:** 2026-11-22 · **Component:** agents (`bin/agents/veil.sh`) · **Plan:** 350 part B

## What was wrong

The first live Veil report from a worker seat wrote its ledger into the worker's private seat state. A seat sets
`BROKK_STATE_OVERRIDE` to its own machine-state dir, and the door read that first. The holder's `veil.sh received`
reads the home's state, so it could never have found the id it was asked to answer.

## What was built

The door now skips an override that is only the seat's machine-state dir. This is the same rule
`eindri_helm_state` uses, so the ledger is always the arm's. The Níðhöggr job no longer forces its own state onto
the Veil.

## Proof

`bash bin/agents/tests/test_veil.sh` — 24 passed, including "a seat's private state is skipped: the ledger is the
arm's".

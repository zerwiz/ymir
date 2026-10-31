# The shim is the door under test

**Date:** 2026-10-31 · **Component:** snotra · **Status:** waived in writing

## What the ward saw

After plan 129's move merged, `path-ledger-guard` flagged three lines in
`bin/time/snotra/tests/test_outbound_gate.py` that name `bin/time/snotra/` — a shelf the ledger
records as superseded by `systems/snotra/`.

## Why the reference is deliberate

That suite's whole proof is *a caller nobody has repointed still works*. It drives the **retired
shims** on purpose: the shim is what an un-repointed caller runs, so the shim is the door under
test. Repointing those three lines to `systems/snotra/` would make the suite test the door every
caller has already been moved to — a different claim, and a weaker one.

RULES/25 asks exactly this of a deliberate reference: waive it **in writing** with the reason, which
is what these three lines now carry (`# allow-superseded-path: …`).

## Known red, named rather than hidden

The suite itself is failing on main — 8 failures and 1 error — inherited from the `gate-outbound`
branch that #450 merged. Its expectations predate the move and the gated `sendUpdates=none` path.
Repairing it is the next piece of the outbound-gate work; this note exists so nobody reads a green
ward as a green suite.

#!/usr/bin/env bash
# behaviour-contracts — 2026-11-22 (plan 350 F): every system's behaviour contract is run (ok · red · skip, a hang is
# red), a turn to red is said once through the Veil, the trouble panel carries the reds, and the review contract
# catches one head handed to review over and over.
gate behaviour-contracts "the contracts read ok, red and skip; a turn to red is said once; the panel carries it" \
     bash "$ROOT/bin/ward/tests/test_contracts.sh"

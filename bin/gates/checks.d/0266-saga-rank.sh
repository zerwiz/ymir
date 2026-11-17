#!/usr/bin/env bash
# saga-rank — the digest prints the ranks, so a seat knows what it is (plan 310 §5.5).
gate saga-rank   "the session digest prints which rank this seat holds and who holds what (plan 310)" \
               bash "$ROOT/bin/time/tests/test_saga_rank.sh"

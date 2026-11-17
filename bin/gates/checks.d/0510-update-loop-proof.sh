#!/usr/bin/env bash
# update-loop-proof — plan 002 §6.2: the heart flips a PROVEN release; it does not prove one.
# Before this, the same candidate was proved every fifteen minutes forever: 6m06s of CPU and a
# fresh round of memory pressure each quarter hour on a box that must not build. The proof here is
# that one pass proves and records, and every later pass reads the record instead of repeating it.
gate update-loop-proof "a candidate is proven once: one pass proves and records, the next reads the record and holds, and a proof from elsewhere makes the heart flip without proving at all" \
     bash "$ROOT/bin/engine/tests/test_update_loop_proof.sh"

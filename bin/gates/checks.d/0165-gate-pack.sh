#!/usr/bin/env bash
# gate-pack — Ymir's gate pack seats into a clone, its planted faults are all refused, and its ledger is judged.
#
# PLAN 372 — every app repository carries the same gates, copied byte for byte from bin/gates/pack/ by
# bin/gates/pack.sh seat. This proves a seat is complete, that the seated repository's own planted-fault test
# passes, that vendor-sync agrees, that an older ledger reads as behind, and that a repository's own files are
# never taken.
gate gate-pack "Ymir's gate pack seats whole, its planted faults are refused, and an older seat reads as behind" \
     bash "$ROOT/bin/gates/tests/test_gate_pack.sh"

#!/usr/bin/env bash
# living-well — 2026-11-22 (plan 350 E): the well is read before work (the brief and the session head ask the one
# recall door, for the work and never for the bearings) and written after it (acclaim, verdict, merge, each fix
# note), and a write the well refuses is queued and retried, never dropped (RULES/20).
gate living-well "recall in every brief and head; episodes at acclaim, verdict, merge and fix note; writes queue, never drop" \
     bash "$ROOT/bin/records/tests/test_living_well.sh"

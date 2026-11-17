#!/usr/bin/env bash
# heavy-slot — plan 002 §6.1: the machine has ONE heavy job at a time, and it says whose job waits.
# The law in `updating.md` (one heavy job at a time) had no mechanism until this door; the proof is
# that a second job waits, names the holder, is reaped when the holder dies, and never runs beside
# the first.
gate heavy-slot "one heavy job at a time: the second waits, names the holder, is reaped when the holder dies, and never runs beside the first" \
     bash "$ROOT/bin/engine/tests/test_heavy_slot.sh"

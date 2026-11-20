#!/usr/bin/env bash
# heavy-slot — plan 002 §6.1, counted since 2026-11-18: the machine carries as many heavy lanes as its
# own registry row says, and a job that finds every lane held says whose job it waits for.
# The law in `updating.md` (a heavy job goes through the slot) had no mechanism until this door; the
# proof is that a job takes a FREE lane, that with every lane held it waits and names the holders,
# that a holder who dies is reaped rather than waited on, and that one more job than the machine
# carries never runs beside the others.
gate heavy-slot "counted heavy lanes: a job takes a free lane, waits and names the holders when every lane is held, is reaped when its holder dies, and never runs beside one too many" \
     bash "$ROOT/bin/engine/tests/test_heavy_slot.sh"

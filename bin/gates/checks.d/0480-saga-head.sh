#!/usr/bin/env bash
# Plan 275 item 28 — Sága's head is SHORT and remembers what it already said: ≤ 60 lines,
# every section answers by name, a finished errand is reported once, and the size test fails
# when the head outgrows its budget (a digest nobody can afford to read is not a digest).
gate saga-head   "Sága's head fits its budget, every section answers by name, finished errands are news once, and ONE hook serves the current home" \
               bash "$ROOT/bin/time/tests/test_saga_head.sh"

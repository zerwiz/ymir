#!/usr/bin/env bash
# landing — Sága names the branches pushed with no PR and the commits on no remote (plan 293).
#
# PLAN 293 part 3 — the digest SEES what never landed: a pushed worker branch with no PR, and a
# commit on no remote. A warning nobody runs is decoration, so the door is proved on a planted
# repository, including the offline path (a branch is never called PR-less on a failed question).
gate landing     "Sága names the branches pushed with no PR and the commits on no remote (plan 293)" \
               bash "$ROOT/bin/time/tests/test_saga_land_warnings.sh"

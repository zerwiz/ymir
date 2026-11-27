#!/usr/bin/env bash
# skirnir-smoke-verdicts — a passing check is never booked as a failure, and the Ymir pitch explains.
#
# Under `--quiet` (the nightly row) every passing check of Skírnir's smoke test also counted as a failure.
gate skirnir-smoke-verdicts "one verdict per smoke check, quiet or not, and a squatted voice port is named" \
     bash "$ROOT/systems/skirnir/tests/test_smoke_verdicts.sh"
gate skirnir-pitch "the Ymir pitch is built from public facts and an archived record never answers" \
     python3 -W ignore -m unittest discover -s "$ROOT/systems/skirnir/services" -p 'test_pitch.py'

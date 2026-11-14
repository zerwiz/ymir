#!/usr/bin/env bash
# unit-drift — an installed unit on a retired value is found and re-seated; a seat's own choice is not drift.
gate unit-drift "an installed unit on a retired value is found and re-seated; a seat's own choice is not drift" \
     bash "$ROOT/bin/engine/tests/test_units_drift.sh"

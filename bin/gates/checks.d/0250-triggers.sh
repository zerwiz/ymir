#!/usr/bin/env bash
# triggers — a smithy starts by a person, the clock or an event — and nothing arms itself.
gate triggers    "a smithy starts by a person, the clock or an event — and nothing arms itself" \
               bash "$ROOT/bin/time/tests/test_event_trigger.sh"

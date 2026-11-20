#!/usr/bin/env bash
# alarm-names-the-machine — 2026-11-20: every alarm line names the machine that raised it, first, so a dev
# machine's cron failure does not read as the heart's. All three senders (cron, garmr, the assistant) go
# through the one door, so the proof is that door.
gate alarm-names-the-machine "an alarm line names its machine, a relay may name another, and the message survives whole" \
     bash "$ROOT/bin/notify/tests/test_send_names_the_machine.sh"

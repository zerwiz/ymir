#!/usr/bin/env bash
# wake-seq — the ack consumes only what was shown, and loses no wake that arrives meanwhile (plan 369 item 16).
gate wake-seq "the wake ack consumes only what the holder was shown and loses no wake that arrives meanwhile" \
     bash "$ROOT/bin/time/tests/test_wake_seq.sh"

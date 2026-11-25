#!/usr/bin/env bash
# clock-lock — the Nornir clock watches the right lock, logs every stop, and is restarted once (plan 369 item 17).
gate clock-lock "the house clock refuses a stray lock pointer, logs every stop, and the panel restarts it once" \
     bash "$ROOT/bin/time/tests/test_clock_lock.sh"

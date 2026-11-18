#!/usr/bin/env bash
# dispatch — the dispatcher proposes once, refuses the fourth attempt, and never renders an
# unreadable input as `0` (bin/dispatch/dispatch.sh, the job on the timer, plan 304 §4.3).
gate dispatch "the dispatcher's three laws hold: unchanged input is a no-op, the same item never becomes two proposals, the fourth attempt is refused, and an unreadable input exits non-zero" \
     python3 "$ROOT/bin/dispatch/tests/test_dispatch.py"

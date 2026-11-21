#!/usr/bin/env bash
# night-report — the morning report counts right, closes his to-do only through the board's door, never
# writes the retired list file, and its Telegram buttons arrive whole (PR #867 and its rework).
gate night-report "the night report counts right, closes cards only through todo.sh, and its buttons fit 64 bytes" \
     python3 "$ROOT/bin/day/tests/test_night_report.py"

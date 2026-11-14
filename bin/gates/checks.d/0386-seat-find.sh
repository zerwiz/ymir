#!/usr/bin/env bash
# seat-find — the finder names the pane whose work printed the words, never its own, and counts what
# it could not read.
gate seat-find "the finder names the pane whose work printed the words, never its own, and counts what it could not read" \
     bash "$ROOT/bin/seat/tests/test_seat_find.sh"

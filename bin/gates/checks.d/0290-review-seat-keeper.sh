# review-seat-keeper — the reviewer's seat refuses aloud, reaps a shell pane and re-raises, and
# names why pi died.
#
# PLAN 293 part 10 — a pane whose agent died is a shell, not the seat: it is reaped and a fresh
# agent raised. A live primary keeps only the helm — never the seat. And when pi dies at start, the
# pane's own first error line is what the keeper reports (RULES/13 is the measured cause), not
# "agent start failed".
gate review-seat-keeper "the reviewer's seat refuses aloud, reaps a shell pane and re-raises, and names why pi died" \
               bash "$ROOT/bin/forge/tests/test_review_seat_keeper.sh"

# liveness-grace — the sweep never calls a live seat dead inside the settling grace.
#
# 2026-11-06 — the sweep judged a LIVE errand dead 3m59s after launch, because herdr
# reported its agent `done` and `done` means idle, not finished. The grace is what makes
# a quiet pane evidence of quiet rather than evidence of death; this is the proof it bites
# both ways (SETTLING inside the window, DEAD past it).
gate liveness-grace "the sweep never calls a live seat dead inside the settling grace" \
     bash "$ROOT/tests/test_eindri_liveness_grace.sh"

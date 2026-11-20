#!/usr/bin/env bash
# learn-home-ship — the nightly home map ships itself, and an unchanged night writes nothing.
#
# The Nornir row at 03:05 rewrote ~1,300 fact files every night for a stamp and committed none,
# so the private home had to be cleaned by hand each morning. The proof runs on a throwaway git
# home with a local bare remote: an unchanged night is 0 writes and 0 commits, a changed source
# ships exactly one commit, `--no-ship` leaves the commit unmade, a gone source retires its copy
# by moving it (Rule 11), and `--dry-run` touches nothing.
gate learn-home-ship "the nightly home map ships its own output and an unchanged night writes nothing" \
     bash "$ROOT/systems/skirnir/tests/test_learn_home_ship.sh"

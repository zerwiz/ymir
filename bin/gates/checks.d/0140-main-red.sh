# main-red — the alarm for a red main names the ward and never fires for a pull request.
#
# A RED MAIN MUST SHOUT (plan 243 part E, 2026-11-11). The gate on main was red for four
# consecutive commits and nothing in the house said so — every hand pushed into it and every push
# failed for drift it had not caused. `bin/gates/main-red.sh` is the alarm; this is the proof that
# it BITES (a finding names the gate and quotes the ward) and that it stays QUIET where it must (a
# green log files nothing, no token calls no API, and only a main push may open the issue).
gate main-red "the alarm for a red main names the ward and never fires for a pull request" \
     bash "$ROOT/bin/gates/tests/test_main_red.sh"

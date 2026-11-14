# gate-directory — the gate list is a directory, and it behaves like one.
#
# Plan 295 fix S1. The proof that two branches adding two gates merge without a conflict, that a
# gate FILE which fails fails the run, that an unloadable gate is a FAIL and never a skip, and that
# an EMPTY list refuses instead of printing a false green. It also holds the shape itself: no gate
# line may come back into ci-verify.sh.
gate gate-directory "the gate list is a directory: two gates merge, a failing file fails the run, an empty list refuses" \
     bash "$ROOT/bin/gates/tests/test_gate_directory.sh"

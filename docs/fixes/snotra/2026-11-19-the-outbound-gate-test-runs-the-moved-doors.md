# The outbound gate test runs the moved doors, and its draft carries the letter mark

**Date:** 2026-11-19 · **Component:** snotra · **Found by:** the letters suites run after tonight's gather

## What was wrong

`bin/time/snotra/tests/test_outbound_gate.py` failed 12 of 16 tests on `main` and on the gathered head alike.

- It still ran the shims under `bin/time/snotra/`. Commit `ca6faff37` retired those shims on purpose ("the move
  is finished"), so every call ended with exit 127.
- One mail test drafted a letter with no `X-Ymir-Letter` line. Since plan 322 the send door refuses such a draft
  before it reads the operator's word. The test meant to prove the word, not the mark.

## What changed

- The test runs the moved doors: `systems/snotra/services/letters/mail-send.sh`,
  `systems/snotra/services/calendar/calendar-invite.sh` and `systems/snotra/services/approve/snotra-approve.sh`.
- The approved-draft test marks its draft `X-Ymir-Letter: undressed · a test draft`, as a door-made draft would
  be marked. The unapproved-draft test is unchanged, and it still proves the refusal.

No door changed. Only the test moved.

## Proof

`python3 bin/time/snotra/tests/test_outbound_gate.py` runs 16 tests and prints `OK`. Before the change it printed
`FAILED (failures=12)`, on `origin/main` as well.

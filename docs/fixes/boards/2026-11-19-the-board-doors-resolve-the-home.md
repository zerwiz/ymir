# The board doors resolve the home instead of guessing it

**Date:** 2026-11-19 · **Component:** boards · **Found by:** the gather's pre-push gates

## What was wrong

`bin/boards/board_people.py` and `bin/boards/plane_base.py` found the operator's home with
`YMIR_HOME`, or else a hard-written path under the user's documents folder. The defaults ward
(`defaults-guard.sh`) refused the gathered head for it. A home moved by the install's record was
missed: the doors would read the wrong members file and the wrong workspace list.

## What changed

Both doors now resolve the home the way the house resolver does. They read `YMIR_HOME` first, then
the install's record at `$XDG_CONFIG_HOME/ymir/home`, and only then the documented default. This is
the same order `bin/mail/gna_store.py` uses.

In the same gather, `bin/voice/tests/test_todo_write.py` gained its executable bit, which the rules
ward asks of every new door.

## Proof

- `defaults-guard.sh check bin/boards` reports no finding.
- `test_gimle_mcp_board.sh`, `test_trello_door.sh` and `test_mcp_seat_quiet_ui.sh` pass.

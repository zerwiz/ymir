# Every plan tool feeds the board, on its owner, with no number taken twice

**Component:** records · **Date:** 2026-11-22

## What was wrong (measured)

- Two machines each filed **plan 352** within twenty minutes. The pi tool `ymir_plan` numbered from a local `ls` of the ledger, with no fetch and no look at the board.
- Plans **350, 351, 355 and the second 352 never reached the board.** The pi tools `ymir_plan` and `ymir_note` wrote the file and never called the card road that `bin/records/plan.sh` and `note.sh` call.
- New plan cards were **unassigned**, so "on me" was not true on the board.
- A plan closed by an **appended** status line stayed in its first state on the board: only the first 45 lines were read.

## What changed

- `.pi/extensions/elder.ts`: `ymir_plan` now runs `bin/records/plan.sh new` (fetch, number, header with Status, index row, card). `ymir_note` runs `bin/boards/plan-card-after.sh` after a verified append.
- `bin/records/plan.sh`: the next number is after the ledger's highest **and** the board's highest (`plan-sync.sh --highest`), bounded by a timeout; off with `YMIR_PLAN_BOARD_CHECK=0`.
- `bin/boards/plan_sync.py`: `--highest`; new cards are assigned to `board.assignee` or the operator's email from the home; the last appended `**Status:**` line wins over the header.
- `bin/boards/board_adapter_mcp.py`: `create_card` passes `assignees` when the board accepts them.
- `bin/mcp/ymir-mcp.py`: three doors every harness can reach: `ymir_veil` (send, steer, received, accepted, rework, status, pending), `ymir_board_sync`, and `ymir_publish`. A test in `bin/gates/tests/test_new_doors.sh` names them, with `gna_fleet_tell`.

## Proof

- `bin/boards/tests/test_plan_owner.py`: 6 ok (owner from the home, the row wins, a list is kept, nobody invented, the board's highest read with steps ignored, an appended status closes the plan).
- `bin/boards/tests/test_plan_sync_*.py`: 0 failed.
- `plan-sync.sh --project ymir --highest` answered `356` against the live board; `plan.sh next --project ymir` answered `357`.
- `ymir-mcp.py --selftest` lists 55 doors, including the three new ones.

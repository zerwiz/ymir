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

## Added to the same change: start date, labels, relations, priority

- **Start date.** `plan_sync.py` reads `**Opened YYYY-MM-DD.**` (or `Opened YYYY-MM-DD`) from the header; with none it uses the date of the file's first commit (`git log --diff-filter=A`). It is sent as `start` on create and set on an existing card only when its start is empty. `plan.sh new` now writes the Opened date with Sól (`bin/time/sol.sh iso`).
- **Assignees backfill.** An existing plan card with no assignee gets `plan_assignees()`; people a person set are never replaced.
- **Topic labels.** A plan declares `Labels: security, ui-ux` (later lines add). With none declared, labels are inferred from the title and first section with the word map in the home, `config/board-topics.yaml` (shipped example: `config/board-topics.yaml.example`, whole words only, no model). A House the plan names is a label too. Labels are ensured, then added to the card on every sync; a label a person set is never removed.
- **Relations.** `Parent: plan N` or `extends plan N` in the first 25 lines sets the card's parent (one, declared only, never replaced). Stands-on plans become `relates_to`, `supersedes` / `superseded by` / `renumbered from` become `duplicate`, `Blocked by: plan N` becomes `blocked_by`, through the contract verb `relate` (`add_relation`; `list_relations` is read first, nothing is removed). On a board without the verb a link carries the relation. Documents named under `hodd/docs/` or `docs/` are attached as links, once each by URL.
- **Priority.** `Priority: urgent|high|medium|low|none` in the header, the last line wins. `plan.sh new` writes `Priority: none` and takes `--priority`; `ymir_plan` (pi and MCP) pass `priority` through. Without a declaration the home's `priorities:` section of `board-topics.yaml` may map a topic to a default; else `none`. Set on create, and later only when the card's priority is none.
- **Proof.** `test_plan_owner.py` also covers: the date parse, the first-commit fallback, a set start never overwritten, declared labels winning, inference from words, a person's label kept, a declared parent set and a mention never a parent, no duplicate links or relations on a second sync, a person's parent and priority kept. The dry run (`plan-sync.sh --project ymir --dry-run`) lists each `backfill`, `labels`, `parent`, `relate` and `link` it would make: 301 cards to backfill, 231 label additions, 3 parents, 24 relations, 249 links.

## CHANGE LOG

- 2026-11-22 — review-mend: added missing heading for #909

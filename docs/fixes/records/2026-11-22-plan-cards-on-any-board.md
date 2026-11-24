## records · unversioned · 2026-11-22 — plan cards on any board, with their done date

### Why
Only one board adapter existed, so a project on Trello, GitHub Projects or no online tool had no plan cards. A closed plan carried no date, and one diagram in plan 355 did not draw because the board's renderer refused a label with a line break (plan 358, Part 7).

### Files
- `bin/boards/board_adapters.py` (new), `bin/boards/plan_sync.py`, `bin/boards/board_adapter_mcp.py`, `bin/boards/tests/test_board_adapters.py` (new)
- `bin/collab/kit/plans/PLAN-ROAD.md`, `bin/collab/kit/plans/board.yaml.example`, `bin/collab/kit/plans/board-topics.yaml.example` (new)
- `docs/features/the-board-contract.md`, `docs/features/plan-sync.md`

### What
`board.adapter` may now be `file`, `github` or `trello`, each answering the same verbs as `mcp`. A card's done date is written when a plan closes: a comment `closed YYYY-MM-DD` and the tool's completed field where there is one. The date comes from the appended status line, else `git blame`. A Mermaid node label with a line break, bracket or colon is quoted before it is sent. The collaboration kit installs the plan road note, the board row template and the topics example.

### Verified
`python3 bin/boards/tests/test_board_adapters.py` runs the same story on all three adapters with fake doors, plus the done date and the diagram. The three older plan-sync tests and `bash bin/collab/tests/test_collab.sh` pass.

## CHANGE LOG

- **2026-11-22** — opened.

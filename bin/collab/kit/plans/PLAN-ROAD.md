# The plan road — how this project's plans reach its board

A plan is a Markdown file in the project's plan ledger. The board shows one card per plan, so people on any
planning tool see the same plans, dates, labels, priority and owner.

## The ledger

- One file per plan: `NNN-short-name.md`, numbered after the highest number in the ledger **and** on the board.
- The header carries `**Opened YYYY-MM-DD.**`, a `**Status:**` line, and optionally `Labels: security, ui-ux`,
  `Priority:` and `Stands on: plan N` or `Blocked by: plan N`.
- A plan is never rewritten to close it. Append a new `**Status:** done YYYY-MM-DD` line. The card records the date
  that line was appended.

## The board

Copy `plans/board.yaml.example` into the project's registry row and pick an adapter:

| Adapter | For a project that uses | Needs |
|---|---|---|
| `mcp` | a board that speaks the board contract over MCP | a URL and a token reference |
| `github` | GitHub Projects (v2) | `gh` signed in, the project number |
| `trello` | Trello | the board id, the seat's Trello grant |
| `file` | no online tool | nothing: a `BOARD.md` table in the project |

Then run `bin/boards/plan-sync.sh` (the pinned runtime carries it). Relations become typed links where the tool has
no relation type.

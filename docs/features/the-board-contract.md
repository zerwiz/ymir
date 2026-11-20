# The board contract — how Ymir talks to a board without knowing its engine

Ymir is public. The people who install it have GitHub, perhaps Trello or Jira, and usually no Gimlé. So Ymir
keeps one **board contract** and leaves each board engine to the place that owns it. This house's own board is
Plane, served by the Gimlé suite, and that code lives in the Gimlé repository.

## What it is

The contract is a small set of verbs over a card: `plans · cards · card · create · move · assign · comment ·
link · cycle · sync-plan`. A card has a title, a state **group** (`backlog · unstarted · started · review ·
done · cancelled`), labels, links and a stable key. Ymir never uses one engine's state names.

Each project's row in the home's registry (`hodd/identity/projects.yaml`) names its board:

```yaml
board:
  adapter: mcp
  place: <the board's address for this project>
  mcp:
    url: https://…/mcp
    token_from: claude-mcp:<server> | env:<NAME> | vault:<NAME>   # a reference, never a value
```

The `mcp` adapter (`bin/boards/board_adapter_mcp.py`) reaches any board that speaks the contract over MCP.
Gimlé's MCP is one such board, and its `board_contract` tool names the tool that answers each verb.

## What you need

- A `board:` block in the project's registry row.
- The token the block names, reachable on this seat. A `claude-mcp:` reference reads Claude's MCP config,
  including a `headersHelper`.

## The commands

```bash
bin/boards/plan-sync.sh --project ymir                      # the plan ledger onto the board
bin/collab/collab.sh publish <repo> --project ymir --dry-run # the baton's §3 and §4 as cards, written with --yes
bin/collab/collab.sh who                                     # the roll; the board column comes from board_roll:
```

For the roll, the operator's register (`hodd/data/collaboration.yaml`) names the command that answers for
the board on its `host:`:

```yaml
board_roll: python3 ~/gimle/src/gimle/systems/board/who-board.py
```

## Limits

- An engine's own features (Plane's pages, views, webhooks, workspace seeding) are not in Ymir. Use the
  board's own MCP for those.
- A project with no `board:` block is refused by name. Nothing is guessed.
- A register with no `board_roll:` shows the board column as `unread` and says why.

## The ward

`bin/gates/guards/board-engine-guard.sh` refuses a **new** file that names Plane's API, the old Gimlé folder under `bin`,
or a Gimlé host from the home's list (`config/gimle-hosts.txt`). It runs at commit and on every push.
A line that must stay can be waived with `board-engine-ok: <why>` on the same line.

## If it does not work

- `the token named by 'claude-mcp:<server>' is not there`: the seat's Claude config has no such MCP server,
  or its header helper printed nothing.
- `project '<id>' has no board: block`: add the block to the registry row.
- The fix note is `docs/fixes/records/2026-11-20-the-board-engine-leaves-for-gimle.md`.

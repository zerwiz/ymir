# The to-do board — your list as cards, through one door

## What it is

Your personal to-do lives on a board, one card per item, not in a long Markdown file. Every house writer files
through one door, `bin/records/todo.sh`. That includes the voice, and any agent over MCP (`ymir_todo_board`). So two
writers never fight over a file, and every item has a state, a due date, an owner and a history.

## What you need

- A board reachable through its MCP door, and a place on it for your list.
- `$YMIR_HOME/config/todo-board.yaml` with `place:` and `mcp_url:` (see the example below).
- A tool token for this machine in `$YMIR_HOME/state/todo-board.token` (mode 0600). Mint it through the door's
  register as `tool:<machine>-board`, scoped to your place only.

```yaml
place: myhome/todo                        # the board place that holds your list
mcp_url: https://board.example.org/mcp
token_file: state/todo-board.token
owners: {}                                # a spoken name -> a board member
agent_mail_domain: agents.example.org     # the address domain for arm-holder members
```

Without the file, the door says `skip` and exits 0, and the voice keeps writing the old file.

## The commands

| Command | What it does |
|---|---|
| `todo.sh add "<what>" --lane Today --due 2026-12-01` | files one card and prints its number |
| `todo.sh list [--lane Waiting]` | lists the cards, newest first |
| `todo.sh move <card> Done` | moves a card to a lane |
| `todo.sh lanes` | shows which lanes are real board states and which ride on a label |
| `todo.sh flush` | sends what was queued while the board was dark |
| `todo.sh migrate --dry-run` | shows how an old `todo.md` would split into cards; `migrate` then files them |
| `arm-members.sh plan` | names the board member each machine's arm holder should have, and who is missing |

The lanes are `Inbox · Today · This week · Waiting · Someday · Done`.

## Limits

- A board with only its default states still works. Each card goes to the nearest state, with the lane as a label.
  Once you create the six states on the board, `move` puts cards into them.
- The board's reader returns at most 100 cards per place, so `list` shows the newest 100.
- `arm-members.sh` creates nobody. The board's admin makes each machine's account.
- The board limits how many calls it takes per minute. A long migration waits and retries by itself.

## If it does not work

- `todo.sh status` says what is missing: the place, the door or the token.
- `the board door refused the token (HTTP 403)` means the token was revoked, or is not scoped to the place.
- `queued` means the board did not answer. Run `todo.sh flush` once it does.

## CHANGE LOG

- **2026-11-20** — written with the change it describes.

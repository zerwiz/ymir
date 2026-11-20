# Plan sync — a project's plans as cards on its board

## What it is

One command that mirrors a project's plan ledger onto that project's board, **one card per plan**. People and agents
can then see, sort and discuss plans where the rest of the work already lives.

The ledger stays the record. The card is a view of it: its title is `NNN · <plan title>`, its label is `plan`, and its
description holds only the plan's number, its home-relative file path and its status word. The plan's own text never
leaves the home.

## What you need

- A project row in `$YMIR_HOME/hodd/identity/projects.yaml` with a `board:` block (below).
- The project's plan ledger in the home (a README index is used when there is one; any `NNN-*.md` at the ledger's root is
  mirrored too).
- A board that speaks the board contract over MCP, and a token for it, **referenced** by name — never written down.

```yaml
board:
  adapter: mcp
  place: <the board's address for this project>
  mcp:
    url: https://<the board's MCP>/mcp
    token_from: claude-mcp:<server>      # or env:<NAME>, or vault:<NAME>
  plans: <home-relative ledger path>     # optional; default records.in_home.plans, then the realm layout
```

## The commands

```bash
bin/boards/plan-sync.sh --project <registry-id> --dry-run   # print what would be created or moved; write nothing
bin/boards/plan-sync.sh --project <registry-id>             # mirror the ledger
bin/boards/plan-sync.sh --project <registry-id> --include-old   # also the reference archive old-plans/
```

The last line reports the counts: `plans=… created=… updated=… unchanged=…`.

## How a status becomes a state

Plan-sync speaks the board contract's **state groups**, never one engine's state names. The `mcp` adapter turns a group
into the board's own state.

| Ledger status begins with | Group |
|---|---|
| `built`, `done`, `landed`, `shipped`, `complete`, `live`, `fixed`, `merged` | `done` |
| `superseded`, `retired`, `withdrawn`, `rejected`, `abandoned`, `cancelled` | `cancelled` |
| `partial`, `active`, `building`, `in progress`, `started` | `started` |
| `approved`, `ready`, `briefed` | `unstarted` |
| anything else (`opened`, `proposed`, no status) | `backlog` |

The status comes from the README index row when it has one, otherwise from the plan's own header.

## Safe to run again

- **Idempotent.** A card is found by its number and title. A second run creates nothing and changes nothing.
- **A move on the board stands.** If someone moves a card by hand, the next run leaves it there until the ledger's own
  status changes.
- **Only its own cards.** It touches cards that carry the `plan` label *and* the `NNN · ` title shape. It never deletes
  a card, and never edits one of yours.
- **A board that hides its older cards stops the run.** Measured 2026-11-20: one board's MCP shows only the newest 100
  cards of a place. When a list is that full, plan-sync refuses to write, because a second pass could not see what the
  first created and would create it again. `--dry-run` still works.
- A board that answers *too many requests* is waited out and retried; writes are paced.

## What it does not do yet

Modules, pages and sub-items need the board engine's own API. That belongs to the board's own suite, not to Ymir. A
project whose board is another tool (Trello, GitHub Projects) needs its adapter, which plan 335 names and this change
does not ship. An unknown `adapter:` is refused by name.

## If it does not work

| You see | It means |
|---|---|
| `has no board: block` | the project's registry row names no board |
| `the token named by '…' is not there` | the reference resolves to nothing on this seat; the value is never printed |
| `HTTP 403` / a Cloudflare 1010 | the request lacked a User-Agent or the token is not allowed in that place |
| `older ones may be hidden` | the board lists only its newest cards; have its owner list the place in full before a write run |
| `no state in the group` | the board has no state for that group; add one on the board |

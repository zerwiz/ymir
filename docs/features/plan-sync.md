# Plan sync — a project's plans as whole cards on its board

## What it is

One command that mirrors a project's plan ledger onto that project's board, **one whole card per plan**. People and
agents can then read, sort and discuss plans where the rest of the work already lives.

The ledger stays the record. The card is a generated view of it, and says so on its first line:

| The card carries | How |
|---|---|
| title `NNN · <plan title>` and the label `plan` | from the ledger's index (or the file's first heading) |
| the plan's full text — headings, tables, lists, quotes, code | sent as Markdown, opened by `🔒 generated from the file — edit the file, not this card` |
| the plan's phases, each with its accept line | **sub-items** `NNN.<id> · <phase>`, each saying `Done means: …` |
| a link, *Plan file in the home* | from `board.file_url`, else the home's own git remote |
| the state | the state **group** from the ledger's status |
| diagrams | the board draws each ```` ```mermaid ```` block where it can; one it cannot draw stays code and is named in the report |

A phase is a row of any table in the plan that has a `#` column, a phase or step column, and an accept or *done means*
column.

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
    token_from: claude-mcp:<server>      # or env:<NAME>, or vault:<NAME>, or a list of these tried in order
  plans: <home-relative ledger path>     # optional; default records.in_home.plans, then the realm layout
  file_url: https://<host>/<repo>/blob/main/{path}   # optional; default from the home's git remote
```

## The commands

```bash
bin/boards/plan-sync.sh --project <registry-id> --dry-run   # print what would be created or changed; write nothing
bin/boards/plan-sync.sh --project <registry-id>             # mirror the whole ledger
bin/boards/plan-sync.sh --project <registry-id> --plan 343  # only one plan (repeatable)
bin/boards/plan-sync.sh --file <path/to/NNN-plan.md>        # one plan; its project is found from the registry
bin/boards/plan-sync.sh --file <path> --road                # only say whether this seat can reach the board
bin/boards/plan-sync.sh --project <registry-id> --include-old   # also the reference archive old-plans/
```

A full run ends with the counts, then the count per place, then anything it could not do:

```
plan-sync acme/Demo: plans=294 created=3 upgraded=288 updated=0 unchanged=3 steps=412 failed=0
count acme/Demo: ledger=294 plans · board=294 plan cards
not synced: plan 77 (…): <why>
not drawn (kept as code): plan 338 diagram 2: <why>
```

## The plan tools keep the board current by themselves

You do not need to run the sync after editing a plan. These tools call `bin/boards/plan-card-after.sh` when they
finish, and it syncs that one plan's card in the background:

| Tool | When |
|---|---|
| `bin/records/plan.sh new` (and the `ymir_plan` MCP tool) | a plan is created |
| `bin/records/note.sh` (and the `ymir_note` MCP tool) | a section is appended to a plan |
| `bin/vault/home-sync.sh ship` (and `ymir_push`) | a plan file is shipped to the home's remote |

It always says what it did, by name — never a silent skip:

| You see | It means |
|---|---|
| `plan-card: plan 343 → <place>: syncing in the background (log: …)` | the card is being brought up to date |
| `plan-card: plan 343: no road to the board on this seat — …` | this seat has no token for the board; the reason follows |
| `plan-card: …: no project with a board: block keeps its plans where … lies` | the plan's project has no board |
| `plan-card: off on this seat (YMIR_PLAN_CARD=0)` | the hook was turned off on purpose |

The log is `~/.local/state/ymir/plan-sync.log` (set `YMIR_PLAN_CARD_LOG` to move it).

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

The status comes from the README index row when it has one, otherwise from the plan's own header. A new sub-item opens
in `unstarted`, or in `done`/`cancelled` when the whole plan is.

## Safe to run again

- **Idempotent.** Every card it writes ends with `[stamp: <group>.<hash>]`. One listing of the place shows every stamp,
  so an unchanged plan is recognised without reading its card, and a second run writes nothing.
- **Short cards are upgraded in place.** A card from the first, one-line pass is found by its number and title and
  rewritten whole. A second card is never made.
- **A move on the board stands.** If someone moves a card by hand, the next run leaves it there until the ledger's own
  status changes.
- **Only its own cards.** It touches cards that carry the `plan` label *and* the `NNN · ` title shape, and their own
  sub-items. It never deletes a card, and never edits one of yours.
- **A board that cannot list a place to its end stops the run.** The board must answer `offset` when listing; one that
  shows only a window would let a second pass create cards again. `--dry-run` still works.
- A board that answers *too many requests* is waited out and retried; writes are paced (`YMIR_BOARD_PACE`, seconds,
  default 1.0), because a board's own API may allow only about 60 calls a minute.

## What it does not do

Modules and pages are not needed: a card with sub-items carries a whole plan. A project whose board is another tool
(Trello, GitHub Projects) needs its adapter, which plan 335 names and this change does not ship. An unknown `adapter:`
is refused by name.

## If it does not work

| You see | It means |
|---|---|
| `has no board: block` | the project's registry row names no board |
| `no road to the board — the token named by '…' is not there` | no reference resolves on this seat; the value is never printed |
| `HTTP 403` / a Cloudflare 1010 | the request lacked a User-Agent or the token is not allowed in that place |
| `cannot list a place to its end` | the board's door is older than the contract; bring it up to date |
| `no state in the group` | the board has no state for that group; add one on the board |
| `not drawn (kept as code)` | the board could not draw that diagram; it shows as code, and a browser with the live renderer still draws it |

## CHANGE LOG

- 2026-11-20 — opened with plan-sync (plan 335, phase 3): one card per plan, through the board contract and the `mcp` adapter.
- 2026-11-20 — whole cards (plan 335, 3b): the full text as Markdown, phases as sub-items, a link, diagrams drawn by the board, a stamp for idempotence; `--plan`, `--file`, `--road`; the plan tools sync a plan's card after every change.

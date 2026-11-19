# The board doors — Trello and Plane from the command line

## What it is

Two commands that let you, or an agent working for you, change a work board properly:

- `bin/boards/trello.sh` speaks Trello's own API;
- `bin/boards/plane.sh` speaks Plane's.

They exist because the hosted Trello connector cannot put a person on a card, create a label, set a
custom field, add an attachment, or change who can see a board. Those are the things a meeting's board
needs most.

Every change either door makes is written to a log with **what changed**, as before and after values.
A card made by an agent must name the record it came from.

## What you need

| Door | Values | Where they live |
|---|---|---|
| Trello | `TRELLO_API_KEY`, `TRELLO_TOKEN` | the vault (`hodd/secrets/platform.env`), or the environment |
| Plane | `PLANE_API_BASE`, `PLANE_API_TOKEN` | the vault, or the environment |

Without them, each door says `skip` and names the value it lacks. It never guesses.

> [!IMPORTANT]
> The Trello key and token belong to **your own** Trello account. Make the key at
> `https://trello.com/power-ups/admin` (create a Power-Up, then *Generate a new API key*). Make the token
> from the *Token* link beside that key. Then store both in the vault, so neither appears in a process
> listing:
>
> ```bash
> bin/vault/hodd-set.sh --stdin TRELLO_API_KEY    # paste the key, then Ctrl-D
> bin/vault/hodd-set.sh --stdin TRELLO_TOKEN      # paste the token, then Ctrl-D
> ```

## The commands

### Trello

```bash
bin/boards/trello.sh status                                   # up (door) as <you> · skip <what is missing>
bin/boards/trello.sh board <board>                             # lists, labels, members, fields, visibility
bin/boards/trello.sh assign <card> ada-lovelace                # a person from members.yaml, a username or a name
bin/boards/trello.sh label-create <board> Ada blue             # makes it once; asking again finds it
bin/boards/trello.sh label-attach <card> Ada
bin/boards/trello.sh field-set <card> Estimate 5               # text, number, date, checkbox or a list option
bin/boards/trello.sh attach <card> https://example.org/minutes.pdf minutes
bin/boards/trello.sh visibility <board> org                    # private · org · public, after the board exists
bin/boards/trello.sh board-create "Weekly sync" --org <workspace> --from-record meeting.json
bin/boards/trello.sh card-create <list> "Send the quote" --source meetings/2026-11-19/record.md#A7
```

`<board>`, `<card>` and `<list>` are Trello ids, or the short code in a board or card link.

A board raised `--from-record` with more than one attendee opens at the workspace's audience (`org`)
and invites them. It is not raised private for one person and then raised again.

A person is found from `hodd/identity/members.yaml`. Add `trello: <username>` to their row when their
Trello name does not match. Someone who is not a member of the board is refused by name, along with the
list of those who are. They join the board first; then they can be assigned.

### Plane

```bash
bin/boards/plane.sh probe                                      # is the base really Plane?
bin/boards/plane.sh status                                     # up (local) · up (door) · skip <why>
bin/boards/plane.sh workspaces                                 # each workspace and its project count
bin/boards/plane.sh cards <workspace> <project>
bin/boards/plane.sh card-create <workspace> <project> "Title" --source <path>#<id> [--state Todo] [--assign ada-lovelace]
bin/boards/plane.sh card-move <workspace> <project> <card#> Done
bin/boards/plane.sh card-assign <workspace> <project> <card#> ada-lovelace
```

Before any call, the door asks the base for its own user (`/api/v1/users/me/`). An address that does
not answer the way Plane does is refused, and the refusal quotes what did answer. For example, a model
server on the same port says `Server: llama.cpp`.

### Where the hall stands

```bash
bin/gimle-hall-status.sh        # (in Gimlé's repository) desk · mcp · share · hall · plane · trello — each: up (local) · up (door) · skip <why>
```

## The log of changes

Each write appends one line to `~/.local/state/ymir/boards-audit.jsonl` (or to `$YMIR_BOARDS_AUDIT`):

```json
{"at": "…", "door": "trello", "action": "assign", "object": "card", "id": "…",
 "changed": {"idMembers": [[], ["…"]]}}
```

A refused write is logged too, with its reason.

## Limits

- The Trello door is proved against a stand-in of Trello's API. Its first live run is the first one
  after the key and token are in the vault.
- Plane's public API has no list of workspaces. The door lists the workspaces you name, from
  `GIMLE_PLANE_WORKSPACES` or the home's `config/gimle/plane-workspaces.txt`.
- Neither door archives or deletes a board.

## If it does not work

| You see | Meaning | Do this |
|---|---|---|
| `skip … TRELLO_API_KEY, TRELLO_TOKEN unset` | no Trello credentials on this seat | store them in the vault (above) |
| `… is not Plane: … Server: llama.cpp` | `PLANE_API_BASE` points at the wrong service | set it to the Plane host |
| `looks like Plane but refused the token` | the token is wrong or revoked | mint a new Plane API token |
| `… is not a member of this board` | the person has not joined | they join, then assign again |
| `needs source: <path>#<id>` | a card with no record behind it | add `--source` |

## CHANGE LOG

- **2026-11-19** — written with the doors (the operator's plan 324, rows F1–F6, F9, F10, F12, F13).

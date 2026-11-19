# The house's own Trello door: people, labels, fields, attachments and visibility

**Component:** `boards` (`bin/boards/trello.sh`, `bin/boards/trello.py`, `bin/boards/board_people.py`,
`bin/boards/board_audit.py`). **Date:** 2026-11-19. **Plan:** the operator's plan 324, rows F1, F2,
F3, F4, F9, F10 and F12.

## What was wrong

The hosted Trello MCP was the only road to Trello, and it cannot do what a meeting's board needs:

- It cannot put a person on a card. Its `add_member` is documented in the field help but missing from
  the action list, so the call is refused before it leaves.
- It cannot create a label, so a card cannot be coloured by owner either.
- It cannot set a custom field, add an attachment, or change a board's visibility after creation.

On 2026-11-19 that left 41 cards with nobody on them. A board for three people had to be raised a
second time, because a board raised private could not be widened in place.

## What was changed

`bin/boards/trello.sh` speaks Trello's own REST API.

| Verb | What it does |
|---|---|
| `assign` | Puts a person on a card. The person is resolved from `members.yaml` (an optional `trello:` handle, otherwise the name), and the board's members are read back. |
| `label-create` | Creates a label. Creating a name that already exists returns the existing label. |
| `label-attach` | Attaches a label to a card. |
| `field-set` | Sets a custom field of type text, number, date, checkbox or list. |
| `attach` | Adds an attachment to a card. |
| `visibility` | Changes a board's visibility after creation. |
| `board-create` | With `--from-record`, raises the board at `org` when the record names more than one attendee, and invites them (F4). |
| `card-create` | Requires `--source <path>#<id>` (F9). |

How the door behaves:

- **Unknown people are refused.** A name that is not a board member is refused, and the refusal lists
  who the members are. The door never assigns a near match.
- **Missing credentials are named.** `TRELLO_API_KEY` and `TRELLO_TOKEN` come from the environment or
  the vault. If either is missing, the door skips cleanly and names it (F10). The two values travel in
  an `Authorization: OAuth` header, never in a URL.
- **Every write is audited.** Each write appends `{door, action, object, id, changed: {field:
  [before, after]}}` to the boards audit (`~/.local/state/ymir/boards-audit.jsonl`, F12). A refusal is
  recorded too.

## How it was proved

`bin/gates/tests/test_trello_door.sh` runs against a stand-in that serves Trello's shapes, and passes
16 checks:

- `members[] = ['adalovelace']` after `assign c1 ada-lovelace`.
- Three labels created, attached, and found again on a second create.
- `Estimate = 5` and the list field `Phase = Beta`.
- An attachment added.
- Visibility `['private', 'org']` after creation.
- A board raised from a three-attendee record at `org` with three invited.
- A card without a source refused, and a card with one carrying it.
- An audit row `{"idMembers": [[], ["u-ada"]]}`.
- The key and token absent from every request URL.

On this machine, `trello.sh status` answers
`skip — TRELLO_API_KEY, TRELLO_TOKEN unset (env or vault)`.

## What this leaves owed

The live proof on the real board waits for one step by the operator: minting a Trello key and token on
his own account and storing them in the vault. The command is in the plan's report. Until then the door
is proved only against the stand-in.

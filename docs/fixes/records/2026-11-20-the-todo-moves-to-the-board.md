## records · unversioned · 2026-11-20 — the operator's to-do moves to a board, through one door

### Why

The operator's to-do was one long Markdown file in the home. Several house writers appended to it (the voice in
the window, and the desk agent through the same voice tools), so they fought over it. A file also has no states,
no dates that sort, no owners and no record of a move. The operator asked for the list to live on his private board,
with every arm holder there as a member who can be tagged (the operator's plan 327).

### What

- **One door, `bin/records/todo.sh`** (`todo_board.py`): `add · list · move · flush · lanes · status · migrate`.
  It files each to-do as one card through the board's MCP door, with a **tool token** (a `tool:<machine>-board`
  subject in the door's register). It never uses a person's login or an admin key. Unconfigured is a clean skip.
- **Lanes** `Inbox · Today · This week · Waiting · Someday · Done`. Where the board has a state of that name, the
  card goes into it. Where it does not (a board on default states), the card goes into the nearest state of the same
  group and carries the lane as a label. This was chosen over waiting for the states: the cards land today, and
  `move` puts each card into its real state once the states exist.
- **Never lost.** A board that does not answer queues the card in `state/todo-board-queue.jsonl`, and `flush` sends
  it. A rate refusal (HTTP 429) waits and retries with back-off. The same item twice is one card (a stable key,
  recorded in `state/todo-board.jsonl`). A card deleted on the board is marked there, so the next add files it afresh.
- **One round trip.** States and labels are remembered for ten minutes, so a spoken to-do costs one call to the door
  (about 0.65 s measured), not three. A refusal naming a label or state forgets the memory and tries once more.
- **The voice writes through it** (`bin/voice/voice_tools.py`): `todo_add`, `todo_list`, `todo_done` and
  `todo_reopen` use the board when the seat has one, and keep the file road for a seat that has none. The desk agent
  reaches the same tools, so both writers go through one door. `todo_update` still edits the file; that is owed.
- **The migration** reads the old list and the voice's record. From the list it takes every `- [ ]` / `- [x]` line
  with its indented continuation, verbatim; the record is replayed, not read from its rendered view. It files one
  card for each item, with a `source:` line naming the file, the line and the headings above it, a `key:` line, and a
  label for the half the item came from. It is idempotent.
- **The MCP tool** `ymir_todo_board` in `bin/mcp/ymir-mcp.py` is a thin call to the same door.
- **Arm holders as members:** `bin/boards/arm-members.sh plan` reads the fleet's arm holders. For each live machine it
  names the member that machine should have, and whether that member is already there. Each member gets an ASCII
  address, a display name that says `(agent)` and names the machine, the role member, and the token subject
  `tool:<machine>-board`. It creates nobody, because the board has no API for making an account.

### Decided without asking, and why

- The door reaches the board through its MCP door, not the board's own API. The MCP door already scopes every write
  by place and audits it by subject, and no seat then needs an admin key.
- The edge in front of the door refuses Python's default agent string with HTTP 403. The door sends a plain client
  name, which also tells it apart in the audit.
- The cache, the queue, the remembered states and the token live in the home's ignored `state/` folder, beside the
  other seat tokens, never in this repository.

### Files

- `bin/records/todo.sh`, `bin/records/todo_board.py`, `bin/records/tests/test_todo_board.py` (new)
- `bin/boards/arm-members.sh`, `bin/boards/arm_members.py`, `bin/boards/tests/test_arm_members.py` (new)
- `bin/voice/voice_tools.py`, `bin/mcp/ymir-mcp.py`
- `docs/features/the-todo-board.md`, `docs/features/_catalogue/entries/02-130-the-todo-board.md` (new)

### Verified

- `python3 bin/records/tests/test_todo_board.py` → `PASS: 0 failed` (23 checks, fake board, fenced home).
- `python3 bin/boards/tests/test_arm_members.py` → `PASS: 0 failed` (10 checks).
- The migration, live on the dev machine, filed 113 open items and 16 done, and the count out equalled the count in.
  The first run met the board's rate limit on 42 items, so the back-off was added. The second run filed exactly those
  42, while 87 read back as already filed. A third run filed 0 (`exists 129`).
- A spoken to-do through the voice tool became a card in 0.88 s and 0.91 s, and the old list's checksum did not
  change. Tick and reopen moved a card to Done and back. Every proof card was deleted afterwards.

### Not done

- **Members are not created.** Each machine needs an account, made by the board's instance admin or by one sign-in
  through the board's login. `arm-members.sh plan` names them; cards can then be assigned to them.
- **The six states are not created.** The MCP door has no tool to make a state, and the seat holds no board admin key.
  Until the states exist, five lanes ride on labels.
- **The board's reader returns at most 100 items per place**, so `list` shows only the newest 100. The cache holds
  every card number. Raising the reader's page size belongs to the board kit.
- The voice's change goes live only after the merge and once the runtime pin moves.

## CHANGE LOG

- **2026-11-20** — opened.

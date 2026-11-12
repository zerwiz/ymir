# Gimlé — the hall, the desk and the MCP

**What it is.** Gimlé is the team's own workspace on Zerwiz's hardware: one door (`gimle.zerwiz.org`), and
behind it the desk — what is due, what was decided, what waits on you — then the places: Plane for projects
and tasks, AFFiNE for documents and databases, Excalidraw for drawing. Snotra's meeting record feeds the desk;
the same record answers the MCP.

**What you need.** A gate account (invitation only), and for the MCP a token minted by the house.

## The addresses

| what | where |
|---|---|
| the door (hall) | https://gimle.zerwiz.org |
| the portal (Authelia) | https://auth.zerwiz.org |
| the board (Plane) | https://board.zerwiz.org |
| code (Forgejo) | https://forgejo.zerwiz.org |
| documents (AFFiNE) | https://affine.zerwiz.org |
| whiteboard (Excalidraw) | https://whiteboard.zerwiz.org |
| book a time (Cal.com) | https://book.zerwiz.org |

## Booking a time

`book.zerwiz.org` is **Cal.com**, one calendar per member, behind the same suite. A counterpart picks a
free slot from the member's own booking page; the meeting then lands in the calendar, and Snotra's ear
writes its record into the desk. That is the loop: **a booking becomes a meeting, and a meeting becomes a
record** — nobody types the minutes twice.

The desk carries it as the **Book** tile, beside Board and Documents.

**The booking page itself is public on purpose.** A person who has no account in the hall must still be
able to choose a time — that is what a booking link is for. The administrative side (sign-in, event types,
settings) is the part that belongs behind the gate; do not put the whole hostname behind Authelia or the
only people who can book are the ones who already have an account.

## Deploying it

The suite runs on one machine (the heart), and a merge reaches it through one door:

```bash
bin/gimle/deploy.sh --check    # what is running, against origin/main — changes nothing
bin/gimle/deploy.sh            # move the checkout, link the code, restart, prove every door
```

A deployment is a version, not a copy: the code lives in a clean checkout beside the private material and is
**linked** into the run directory, so `git rev-parse HEAD` answers "what is running" from either end. A door
that does not answer 200 fails the deploy even when systemd says `active`.

## The mirrored documents

The hourly mirror copies a project's status documents onto the heart; the desk serves them at
`/desk/docs/<project>/<file>`, behind the same membership rule as the record — a person who may not see a
place may not read its mirrored documents either. Only flat `.md`, `.html` and `.txt` names are served, and
nothing outside the project's own directory.

## The desk

`bin/gimle/desk.py` renders the page behind the door: **due this week**, **last decisions**, **questions
waiting on me**, then the tiles. It reads a JSON the projector writes and trusts `Remote-User` from Authelia
(Caddy passes it). It never writes.

```bash
bin/gimle/desk.py --port 8487 --data /srv/gimle-desk/meetings.json
```

## The MCP

`bin/gimle/mcp-read.py` is one MCP server for the suite, JSON-RPC over `POST /mcp`. With `--plane` it reads
**the board** as truth for places, cards and owners — through the same `plane_reader.py` the desk uses, so the
two faces of the hall can never disagree about what a board holds.

```
who_am_i · list_places · my_tasks · place_board · meeting_record · who_owes_what · find_doc · read_scene
create_card · update_card      (only when the server is started with --allow-write)
list_plans                     (the mirrored plan documents the hall serves at /desk/docs)
```

**A place is a project on the board**, named `<workspace>/<project>` (`whynotproductions/Ymir`). A token's
place column holds the short names people use (`Ymir`, `Example4`, `Growth`); the server resolves each to the
one project it names and answers `unresolved_places` for anything that is not a place at all — a person in a
place column is refused by name, never answered with an empty board.

**Scope is the place on the token**, enforced by identity, and a refusal says which places the caller may
touch. `my_tasks` returns only cards inside those places.

**Write is off by default.** Without `--allow-write`, `create_card` and `update_card` answer a plain refusal
naming the flag; with it, a card is filed or moved and the audit line carries the reason either way.

Auth is `Authorization: Bearer <token>` (one token per line in `mcp-tokens`, as `<token> <subject> <places>
[fleet]`; a subject may hold more than one token). Every call is appended to `access.jsonl` as `at · subject ·
fleet · tool · verdict · why`, and a refusal records the reason — a read-only door and a missing place are
different faults and must read differently. A call without a valid token is refused **and recorded**.

```bash
# read the board
python3 bin/gimle/mcp-read.py --port 8489 --plane \
  --data ~/gimle/desk/data/meetings.json --tokens ~/gimle/desk/etc/mcp-tokens \
  --audit ~/gimle/desk/data/access.jsonl --docs ~/gimle/desk/data/docs

bin/gates/tests/test_gimle_mcp_board.sh     # the board face, proved against a stub
```

**Limits, said plainly.** The MCP is bound to `127.0.0.1` on the heart and is **not** yet published on a
hostname, so a collaborator on another machine cannot reach it — that is plan 217's G0. `find_doc` and
`read_scene` still answer an honest `isError` with their reason (`AFFiNE` has no token in the house's hands;
a scene must be shared with consent). `list_plans` reads the mirrored documents and says so when a project has
no mirror yet.

**If it does not work.** `systemctl --user status gimle-desk gimle-mcp`; `curl -H "Remote-User: you"
http://127.0.0.1:8487/` for the desk; `curl -X POST http://127.0.0.1:8489/mcp -H 'Authorization: Bearer …'
-d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'` for the MCP. 401 means the token is not in the file; a
recorded refusal means it is.

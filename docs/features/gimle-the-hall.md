# Gimlé — the hall, the desk and the MCP

**What it is.** Gimlé is the team's own workspace on Zerwiz's hardware: one door (`gimle.zerwiz.org`), and
behind it the desk — what is due, what was decided, what waits on you — then the places: Plane for projects
and tasks, AFFiNE for documents and databases, Excalidraw for drawing. Snotra's meeting record feeds the desk;
the same record answers the MCP.

**What you need.** A gate account (invitation only), and for the MCP a token minted by the house.

**A second house.** This page is the first installation's. A different company running its **own** copy — its
own service account, names, gate secrets and members, sharing no secret or document with this one — is a
separate act with its own page: [a-second-house-suite.md](a-second-house-suite.md).

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

## 2026-11-19 — the MCP door logs its people in

This section adds to **The MCP** above; the text there stays as the record of what was built first.

The door that serves the board today is `bin/gimle/mcp/gimle-mcp.py`, a copy of the one the heart runs from
the Gimlé kit. It now admits a caller by one of two roads, and every line of `access.jsonl` says which:

- **`bearer-file`**: a static token from the token file, exactly as before;
- **`oauth`**: a login through an OpenID Connect issuer. The suite's issuer for this is **Dex**, which logs
  people in with Google or GitHub. Start the door with `--oauth-issuer` to turn it on.

**Groups decide what an OAuth caller may touch:** `gimle-all` is every place, `gimle-place-<Name>` is one
place, and `gimle-write` allows writing on a door started with `--allow-write`. No place group means no
places.

**Two faults are fixed for everyone.** The canvas writes (`add_elements`, `update_elements`, `save_room`,
`share_room`) are now refused on a read-only door, for static tokens too. A place name in the token file may
now contain a space, because places are split on commas only.

How to install it, which steps need the operator, and how a person connects are in
[`bin/gimle/mcp/README.md`](../../bin/gimle/mcp/README.md). The proof is two scripts:

```bash
python3 bin/gimle/mcp/test_oauth_door.py    # against a stand-in issuer
python3 bin/gimle/mcp/test_dex_login.py     # against the shipped Dex config, in docker
```

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-15** — a pointer added to [a-second-house-suite.md](a-second-house-suite.md): a different company
  running its own copy of the suite, sharing no secret and no document with this installation.
- **2026-11-19** — appended *the MCP door logs its people in*: the OAuth road, groups for scope, the canvas
  write gate and comma-only places (plan 149).
- **2026-11-19** — appended *the hall's code lives in Gimlé's own repository* (below): the `bin/gimle/` paths
  above name where the code lived until this day.
- **2026-11-19** — appended *two keys to write, a source on every card, and a status that names its road*
  (plan 324): see the section below.

## 2026-11-19 — the hall's code lives in Gimlé's own repository

The commands above name `bin/gimle/…` and `bin/gates/tests/test_gimle_mcp_board.sh`. Those files have **left
Ymir**: Gimlé has its own repository (`zerwiz/gimle`), and its code belongs there, not in the public Ymir
tree. The sections above stay as the record of how the hall was run while the code lived here.

| What | Where it lived in Ymir | Where it lives now |
|---|---|---|
| The desk | `bin/gimle/desk.py` | Gimlé's checkout: `desk/desk.py` |
| The MCP | `bin/gimle/mcp-read.py` | Gimlé's checkout: `systems/mcp/gimle-mcp.py` (the door that serves the board today) |
| The board reader | `bin/gimle/plane_reader.py` | Gimlé's checkout: `desk/plane_reader.py` |
| The share door | `bin/gimle/share-scene.py` | Gimlé's checkout: `desk/share-scene.py` |
| The whiteboard backend | `bin/gimle/brokk-backend.py` | Gimlé's checkout: `desk/brokk-backend.py` |
| The deploy door, the projector, the acceptance script, the board test | `bin/gimle/deploy.sh`, `project.py`, `project-and-publish.sh`, `whiteboard-acceptance.mjs`, `bin/gates/tests/test_gimle_mcp_board.sh` | Not yet in Gimlé's repository; kept verbatim in the operator's home at `hodd/reference/ymir-moved/gimle-bin-2026-11-19/` until that carry lands |

**What Ymir still does.** The voice reads the board through Gimlé's own reader on the heart.
`GIMLE_READER_DIR` names that reader's folder on the heart (default `~/gimle/desk`, Gimlé's checkout).

> [!IMPORTANT]
> Ymir's newer `desk.py` (with the apps section), the reader and the door changes of plan 324 are carried on
> Gimlé's branch `eindri/desk-apps-and-door`, which also turns the heart's desk and share links into real files.
> Still owed in `zerwiz/gimle`: the deploy door, the projector, the acceptance script and the board test. Until
> they land, run them from the home's reference shelf.

## Two keys to write, a source on every card (plan 324)

This is Gimlé's door, so the change lives in Gimlé's repository (`systems/mcp/gimle-mcp.py`, `systems/mcp/plane_tools.py`, `desk/plane_reader.py`), on its branch `eindri/desk-apps-and-door`. It reaches the live door when the heart's Gimlé checkout moves to it.

**Writing now takes two keys.** The door must be started with `--allow-write`, *and* the token's line must
carry the word `write`:

```
<token> <subject> <places> [fleet=<name>] write
```

A line without `write` still reads. On a writable door its `create_card` is refused with
`this token carries no write grant`, and the refusal is written to `access.jsonl`.

**Every card says where it came from.** `create_card` requires `source: <path>#<id>`, the record the card
was made from (for example `meetings/2026-11-19/record.md#A7`). The source is written onto the card.

**A write records what it changed.** Its audit line carries
`change: {object, id, card, place, fields: {field: [before, after]}}`.

**A missing board says so.** A door started `--plane` with no base, an empty token file, or a base that
is not Plane answers every board tool with `isError` naming the missing value. It never answers with an
empty list. No Plane base is defaulted any more (the old default was a model server's port on a dev
machine).

**Which road answered:** Gimlé's `bin/gimle-hall-status.sh` prints `up (local)`, `up (door)` or `skip <why>` for
the desk, the MCP, the share, the hosted hall, Plane and Trello.

The board doors themselves, Trello's and Plane's, are on [the-board-doors.md](the-board-doors.md).

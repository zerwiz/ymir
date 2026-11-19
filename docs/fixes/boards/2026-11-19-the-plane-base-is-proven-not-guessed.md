# The Plane base is proven, never guessed

**Component:** `boards` (`bin/boards/plane.sh`, `bin/boards/plane_base.py`, `bin/boards/plane_cards.py`),
with the two readers that defaulted a base (`bin/gimle/project.py`, `bin/gimle/plane_reader.py`).
**Date:** 2026-11-19. **Plan:** the operator's plan 324, rows F5, F6, F10 and F13.

## What was wrong

The projector and the desk's reader both fell back to `http://127.0.0.1:8099` when no Plane base was set.
On a dev machine that port is a model server. A token set without repointing would have posted cards
at a model, and nothing would have said so.

The Plane door itself had no card verbs, and it read the token straight from the vault with no proof
that the base it was about to call was Plane at all.

## What was changed

- **One resolver, no default.** `plane_base.py` reads the base from `PLANE_API_BASE` (the older names
  `PLANE_API` and `GIMLE_PLANE_URL` still count), and the token from `PLANE_API_TOKEN`, a token file, or
  the vault. A value that is missing is named, and the door skips cleanly.
- **The base is proven first.** Before any call, `GET /api/v1/users/me/` must answer the way Plane does
  (an `id` and an email or display name). Anything else is refused, and the refusal quotes the status,
  the `Server` header and the start of the body.
- **The path the plan named was wrong, and the code says so.** On a real Plane, `GET /api/v1/workspaces/`
  answers 404, because the public API has no workspace listing. Identity is proven on `users/me`, and
  workspaces are then listed one slug at a time from the operator's own list.
- **Card verbs.** `plane.sh cards`, `card-create` (which requires `--source <path>#<id>`), `card-move` and
  `card-assign`, where a person resolves through `members.yaml` and the workspace's members. Every write
  appends what it changed to the boards audit.
- **`plane.sh status`** prints `up (local)`, `up (door)` or `skip <the missing value>`. It never prints
  nothing.
- The projector and the reader lose their default, and both resolve through the same door.

## How it was proved

- This machine, where port 8099 is the model server:
  `PLANE_API_BASE=http://127.0.0.1:8099 plane.sh probe` exits 1 with
  `… is not Plane: GET /api/v1/users/me/ answered HTTP 401, Server: llama.cpp …`.
- The heart, against the real Plane, using its own token file (copied nowhere):
  `plane.sh probe` gives `answered /api/v1/users/me/ as Plane`, and `plane.sh workspaces` lists five
  named workspaces. Three are reachable with 7, 17 and 1 projects, and two answer HTTP 403 to this token.
  `plane.sh status` gives `up (local)`, and `plane.sh cards` read 100 cards from one project.
- `bin/gates/tests/test_gimle_mcp_board.sh` case 13 shows a door pointed at a stand-in that answers like
  the model server, refused by name.

## Where the reader half went (2026-11-19, the split)

This change was written on a branch that also edited `bin/gimle/project.py`, `bin/gimle/plane_reader.py`, the MCP door
and `bin/gates/tests/test_gimle_mcp_board.sh`. That folder left Ymir in the same batch. Only the board door's half
(`bin/boards/`) lands here. The reader and door half landed in Gimlé's own repository, on its branch
`eindri/desk-apps-and-door`, with its own tests. The branch versions of all four files, `project.py` included, are kept
in the operator's home under `hodd/reference/ymir-moved/gimle-bin-2026-11-19/branch-versions/`.

# 2026-11-20 — the board engine leaves for Gimlé; Ymir keeps the contract

**Component:** records (`bin/boards/`), with `bin/collab/`, `bin/voice/voice_tools.py` and a new ward in `bin/gates/`.

**Plan:** 335 phase 7, *the split*, and plan 324's two constraints. Card YMIRPLATFOR-217.

## Why

Ymir is public, and the people who install it rarely have Plane or Gimlé. Plane is the board this house chose,
served by its own suite. So Ymir keeps the **board contract** (the verbs, the card shape, the state groups and
the adapters), and Gimlé keeps Plane. Until today Ymir still carried a Plane door, a copy of the desk and an
older MCP, the whiteboard services, and two collaboration doors that called Plane directly.

## What left, and where it went

Every path left **with its history** for `zerwiz/gimle` (PR #15 there). It was cut with `git filter-repo` and
merged with `--allow-unrelated-histories`. Where Gimlé already held a newer copy, Gimlé's was kept.

| Left Ymir | Lives in zerwiz/gimle |
|---|---|
| `bin/boards/plane.sh` | `systems/board/plane.sh` |
| `bin/gimle/` (nine files) | `desk/`, `bin/gimle-deploy.sh`, `systems/board/`, `apps/whiteboard/bin/` |
| `systems/whiteboard/` | `apps/whiteboard/` |
| `bin/gates/tests/test_gimle_mcp_board.sh` | `desk/tests/test_mcp_board.sh` |
| the Plane half of `bin/collab/publish.py` | `systems/board/publish-baton.py` |
| the Plane half of `bin/collab/who.py` | `systems/board/who-board.py` |

**The Rule 11 record was written first.** Every file is copied verbatim, with `SHA256SUMS`, under the home at
`hodd/reference/ymir-moved/gimle-2026-11-20/`. The removal is logged with its destination in
`hodd/memory/deleted-on-purpose.log`.

## What Ymir does now instead

- **`collab.sh publish`** files the baton's §3 and §4 bullets through the project's `board:` block and the
  `mcp` adapter, the same road as `plan-sync.sh`. Cards are labelled `baton`, open in the `unstarted` group
  and carry their source (`handoff/CURRENT.md#s3-1`). It stays idempotent by title, labelled or not.
- **`collab.sh who`** no longer reads Plane's database. The register names a `board_roll:` command, which
  runs on its host and answers in the roll contract (`{state, users, members}`). The old `plane:` account
  key and old captures are still read.
- **The voice `gimle` tool and `read_board`** reach the board only through Gimlé's MCP (`my_tasks`,
  `list_places`). They no longer import Gimlé's reader from a Ymir checkout or read Plane's API with the
  desk's token.
- **The adapter** gains two small things. `create_card(…, source=)` serves a board that asks where an agent's
  card came from (Gimlé's create needs it). `find_cards(None, text)` finds a card that was never labelled.
  The `claude-mcp:` token road also reads a `headersHelper`, which is how this seat hands Gimlé's token.

## Ymir's MCP is whole

`bin/mcp/ymir-mcp.py` is untouched. None of its tools called a moved file.

## The ward

`bin/gates/guards/board-engine-guard.sh` refuses a **new** file that names Plane's API
(`/api/v1/workspaces/`, `PLANE_API_TOKEN`, `PLANE_API_BASE`, `plane_reader`, `plane-selfhost`), the old
`bin/gimle/` tree, or a Gimlé host from the home's own list (`config/gimle-hosts.txt`). It prints which
list **entry** matched, never the host. It is seated in `.githooks/pre-commit` (section 6) and in
`bin/gates/guards.sh`'s list, so pre-push and CI run it too. Existing files, `docs/fixes/` and `RULES/` keep
their record.

## Proof

```
bash bin/gates/tests/test_board_engine_guard.sh      PASS
python3 -m unittest tests/test_collab_publish_contract.py tests/test_plan_sync.py   8 tests OK
bash bin/collab/tests/test_collab.sh                 28 passed, 1 failed (the failure, "a complete baton passes",
                                                     fails the same on a clean origin/main 444316421)
collab.sh publish <fixture> --project ymir --dry-run board "whynotproductions/Ymir (mcp adapter)", would create 2
```

## Owed

- After Gimlé's PR #15 is deployed by the heart's keeper: `board_roll` in the register points at
  `~/gimle-rel/current/systems/board/who-board.py`. Until that release is current, the board column reads
  `unread` and says why.
- Open PR #840 (a gather) edits `bin/gimle/mcp-read.py`, which this change removes. That card-door hunk
  belongs in Gimlé's `systems/mcp/plane_tools.py`, where the newer MCP lives.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #852

# Gimlé's code leaves Ymir's `bin/gimle/`

**Component:** `gimle` (the nine files under `bin/gimle/`, and the one test that exercised them).
**Date:** 2026-11-19. At the Allfather's word: *"gimle are where he belongs."*

## What was wrong

`bin/gimle/` was still tracked on `main`. It held nine files: `brokk-backend.py`, `deploy.sh`, `desk.py`,
`mcp-read.py`, `plane_reader.py`, `project-and-publish.sh`, `project.py`, `share-scene.py` and
`whiteboard-acceptance.mjs`. Gimlé has its own repository (`zerwiz/gimle`), so this was a second copy in the
wrong house. The MCP door had already left the same way earlier the same day
(`2026-11-19-the-door-leaves-ymir-for-gimle-repo.md`).

## What moved

Every file was copied first, verbatim, to the operator's home at
`hodd/reference/ymir-moved/gimle-bin-2026-11-19/`, with a `SHA256SUMS` list (`sha256sum -c` passes for all
ten). The home commit was shipped before anything was removed here. The removal is a move under Rule 11.

| File | Where Gimlé already carries it |
|---|---|
| `desk.py`, `share-scene.py`, `plane_reader.py`, `brokk-backend.py`, `mcp-read.py` | tracked in Gimlé's repository under `desk/` and `systems/desk/` |
| `deploy.sh`, `project.py`, `project-and-publish.sh`, `whiteboard-acceptance.mjs` | not yet; the home copy is the only one |
| `bin/gates/tests/test_gimle_mcp_board.sh` | not yet; it tests `mcp-read.py`, so it leaves with it |

## Who pointed at it, and what each one does now

| Reference | Change |
|---|---|
| `bin/voice/voice_tools.py`, two places | The board road ran `cd ~/ymir` on the heart and imported Ymir's copy of `plane_reader`. It now imports Gimlé's own reader from Gimlé's checkout on the heart. `GIMLE_READER_DIR` names that folder; the one default is `~/gimle/desk`, the same checkout whose `desk/etc/` already holds the board token. |
| `bin/gates/tests/test_gimle_mcp_board.sh` | Its old body moved with the code it tested (above). The gate stays, rewritten: it finds Gimlé through `bin/apps/app-path.sh` (the dev road `YMIR_APP_GIMLE_DIR`, or the app's own home once Gimlé is installed there) and runs Gimlé's own door suites from it. With no Gimlé copy on the machine it says `skip:` and how to name one. |
| `bin/README.md`, `bin/gates/INDEX.md` | Rebuilt by `bin/gates/inventory.sh` after the `gimle` row left `bin/gates/registers/folders.tsv`. |
| `.agents/assets/agents/capabilities.md` and `capabilities/gates.md` | Rebuilt by `bin/gates/capabilities.sh`. |
| `.agents/tenant-baseline.json`, `.agents/config/tenant-baseline.json` | The `bin/gimle/desk.py` key was dropped. No generator for these files exists in the tree any more (the tenant guard that wrote them is gone), so the key was removed by a script that round-trips the JSON in its own layout. |
| `RULES/02-agents.md` | Append-only: a CHANGE LOG line says where the deploy shape it cites now lives. The law is unchanged. |
| `docs/features/gimle-the-hall.md`, `whiteboard-boards-that-keep.md`, `the-collaboration-doors.md`, two catalogue rows | Append-only: a dated section or line maps each old path to its new home. |

Older fix notes that name `bin/gimle/…` are records of their day and stay as written.

## Proof

```
$ ssh <heart> '<voice_tools board snippet, with GIMLE_READER_DIR at its default>'
rc 0
reader at <heart home>/gimle/desk/plane_reader.py
no board identity mapped for nobody-in-particular
```

The voice suites were run before and after the change, with the same results:
`rodd-hands.test.sh` 8 ok / 1 not ok (`arm_who`), and `context-left.test.sh` 5 ok / 10 not ok. The failures
are the same on unchanged `main`, so this change adds none.

> [!IMPORTANT]
> **Owed before this change reaches the heart's runtime.** On the heart, Gimlé's checkout links `desk/desk.py`
> and `desk/share-scene.py` (and the `systems/desk/` twins) into `~/ymir-runtime/bin/gimle/`. Once that
> runtime moves past this change, those links point at nothing, and `gimle-desk` and `gimle-share` stop.
> Gimlé's own tracked copies sit underneath those links (git shows them as type changes). So the cut-over is
> to restore them, or carry Ymir's newer `desk.py` from the home shelf, in a `zerwiz/gimle` pull request
> **before** the heart's runtime is moved.
>
> Also owed in `zerwiz/gimle`: the deploy door, the projector pair and the acceptance script.

## The carry into Gimlé (added the same day, by the split errand)

The desk's real files (replacing the heart's links), the apps section (plan 325), and plan 324's reader and door
changes are on Gimlé's branch `eindri/desk-apps-and-door`, with their own fix notes and suites. The newer
`bin/gimle` versions from two unmerged Ymir branches (`eindri/mcp-mend-324`, `eindri/gimle-desk-apps`) were kept
first in the home under `hodd/reference/ymir-moved/gimle-bin-2026-11-19/branch-versions/`, with `SHA256SUMS`.

Proof of the rewritten gate: with no Gimlé copy, `skip: no Gimlé copy on this machine`, exit 0. With
`YMIR_APP_GIMLE_DIR` at that branch: `test_write_grant.py` 7 passed, `test_plane_tools.py` OK,
`test_plane_reader.py` OK, `green`.

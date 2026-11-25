---
title: "The board sync: plans and tickets on Plane, and moving cards"
type: "handoff"
product: "kit"
status: "accepted"
owner: "the project's collaboration-kit owner"
created: "2026-11-25"
updated: "2026-11-25"
---

# The board sync: plans and tickets on Plane, and moving cards

This page is for people and for agents. It says what the two board scripts do, how to run them safely, and what
Plane itself already does. Read it before you touch the board.

## At a glance

| I want to… | Do this |
|---|---|
| Put my plans and tickets on the board | `python3 scripts/board_sync.py` (dry run), then `--apply` |
| Move a card to another project | `python3 scripts/board_move.py ATLAS-282 --to NOVI` (dry run), then `--apply` |
| Rename, add or delete a column | In Plane: the project, **Settings**, **States** (see below) |
| See each plan's status | `python3 scripts/status.py` |

## What `board_sync.py` does

It reads the header of every plan and ticket in `plans/` and keeps one Plane card per file. It is one way: the
files win, the board follows. Run it with no flag first. It prints what it would create or change and writes nothing.

| It writes | From the header field |
|---|---|
| Card title | `title`, with the `id` in front |
| Column (state) | `status` |
| Priority | `priority` |
| People | `owner`, `assignee`, `co_owners` |
| Labels | `labels` and `type` |
| Dates | `start`, `due` |
| Parent card | `parent` |
| A block at the top of the description | `created`, `updated`, `product`, `legacy_id`, `reviewer`, source file, `links` |

Text a person writes under that block is kept. The script never deletes a card, never moves one, and never edits a file.
Documents are not cards unless you pass `--only docs`.

## Setting it up in a repository

1. Copy `plans/.board.json.example` to `plans/.board.json` and fill in the board's address, the workspace, and which
   `product` belongs to which Plane project. Add `people` aliases when a header names a person by a name Plane does not know.
2. Put the Plane API token in the environment variable the config names (`PLANE_API_TOKEN` by default). The token lives in
   the vault. It is never written in a file or a commit.
3. Give every plan a header with `product`, `created` and `updated` (see `docs/headers.md`).
4. Run the dry run, read it, then run with `--apply`.

## Rules for agents

- **Dry run first, always.** Show the output to the person before `--apply`.
- **Never apply on a word like "go ahead" given about something else.** The person must have asked for the board to change.
- **Assignees:** the script sets the card's people to the header's owners. If a card has people the header does not name, ask first.
- **Never paste the token** into chat, a file or a commit message.
- A header that names a person Plane does not know is reported as a warning. Fix the alias; do not guess an email.

## Moving a card to another project

Plane Community 1.4 cannot move a card between projects. `board_move.py` copies it instead: the new card gets the title,
description, priority, people, labels, dates and comments, and starts with `Moved from ATLAS-282`. The old card gets
`Moved to NOVI-7` and goes to its project's Cancelled column. **The new card has a new number.** Fix links that name the
old one. If the card is synced to a plan file, change that file's `product` to the new project so the next sync agrees.

## Columns, lists and boards in Plane itself

The columns on a Plane board are the project's **states**. A project admin manages them in the project's **Settings**,
then **States**: rename a state, add one, change its colour or order, or delete it. A state that still holds cards cannot
be deleted; move its cards to another column first. Plane keeps at least one state in each group (backlog, unstarted,
started, completed, cancelled). If the people who need to change columns cannot see the Settings page, their role in the
project is below admin.

## If something goes wrong

| What you see | What it means |
|---|---|
| `PLANE_API_TOKEN is empty` | The token is not in the environment. Get it from the vault. |
| `403 Forbidden` | The board's address refused the request. Check the URL and that the token is current. |
| `maps to no Plane project` | A header's `product` is missing from `plans/.board.json`. |
| `maps to no state` | A header's `status` has no column. Add it under `states` in the config or rename the column. |
| `is not a member of the workspace` | A name in a header matches no Plane user. Add a `people` alias. |

## References

- `scripts/board_sync.py`, `scripts/board_move.py`, `scripts/status.py`
- `docs/headers.md` (the header fields)
- `plans/.board.json.example`

## CHANGE LOG

- 2026-11-25 — written with the first release of the sync.

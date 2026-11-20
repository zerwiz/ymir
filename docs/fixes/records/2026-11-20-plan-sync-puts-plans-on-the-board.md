# 2026-11-20 — plans go onto the board, one card each

**Component:** records (`bin/boards/plan-sync.sh`, `bin/boards/plan_sync.py`, `bin/boards/board_adapter_mcp.py`).

**Plan:** 335 — plans on the board, phase 3, and its appended section "the split".

## What was missing

A project's plans lived only as files in the home. Nobody could see which plan was open, building or done on the board
where the rest of the work is tracked, and nothing kept the two in step.

## What this change adds

`plan-sync.sh --project <id>` mirrors the project's plan ledger onto its board, one card per plan. The card carries the
title `NNN · <plan title>`, the label `plan`, a state from the ledger's status, and a description holding only the
plan's number, home-relative path and status word. The plan's text is never copied.

It is built to the split in plan 335. The sync speaks only the board contract's **state groups** (backlog, unstarted,
started, review, done, cancelled). The generic `mcp` adapter, selected by `board.adapter` in the project's registry row,
reads the URL and a token *reference* from config and turns a group into the board's own state name. No board engine,
URL or state name is written in this repository.

| Behaviour | How it is kept |
|---|---|
| Idempotent | a card is found by number and title; a second run changes nothing |
| Safe | only cards with the `plan` label and the `NNN · ` title shape are touched; nothing is deleted |
| Hand moves stand | a card moved on the board stays until the ledger's own status changes |
| Rate limits | a rate-limited or failing board is waited out and retried; writes are paced |

## Proof

`tests/test_plan_sync.py` runs against a stub board: the first run creates three cards, the second creates none, and a
status flip moves exactly one. It also proves that a stranger's cards are left alone, a dry run writes nothing, and a
project with no `board:` block is refused.

## Left for later

The board engine's own API (modules, pages, sub-items, views) belongs to its own suite and is not reached here. Adapters
for Trello and GitHub Projects are named in plan 335 and are not part of this change. The home's registry carries the
`board:` blocks for the Ymir and Gimlé projects; those are home changes and ship separately.

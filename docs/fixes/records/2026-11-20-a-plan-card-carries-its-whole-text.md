# 2026-11-20 — a plan's card carries the whole plan, and the plan tools keep it current

**Component:** records (`bin/boards/plan_sync.py`, `bin/boards/board_adapter_mcp.py`, `bin/boards/plan-card-after.sh`,
and the calls in `bin/records/plan.sh`, `bin/records/note.sh`, `bin/vault/home-sync.sh`).

**Plan:** 335 — plans on the board, phase 3b ("one card carries the whole plan"), and the operator's added items 5–7.

## What was missing

The first pass of plan-sync (`docs/fixes/records/2026-11-20-plan-sync-puts-plans-on-the-board.md`) put one line per plan
on the board: number, path and status word, never the text. The operator then asked for the whole plan on its card, as a
hand-made example card had shown it could be, and for the board to stay current without anyone running the sync.

That first fix note said *"the plan's text is never copied"*. That was the rule then; the operator has since decided the
opposite for his own board (plan 335, section appended 2026-11-20 evening). This note supersedes that sentence.

## What this change does

| Part | Change |
|---|---|
| the card | the plan's full text as Markdown, opened by `🔒 generated from the file — edit the file, not this card`; its phases as **sub-items** `NNN.<id> · <phase>` with `Done means: …`; a link to the file; the label and state as before |
| idempotence | every card it writes ends with `[stamp: <group>.<hash>]`. The adapter lists the whole place once (paged with `offset`), so an unchanged plan is recognised without reading its card, and a second run writes nothing. A board's own API may allow only ~60 calls a minute, so this matters at 300 plans |
| short cards | upgraded **in place**: found by number and title, rewritten whole; never a second card, never a delete |
| the contract | the adapter gains `list_all`, `add_link`, a card `parent`, `fmt="markdown"` and a `source`. It reads the board's `tools/list` once and sends a field only when the board takes it, so an older board is spoken to as it is |
| a board that cannot page | refused a write by name (it would let a second pass create cards again); the old 100-card guess is gone |
| `--plan`, `--file`, `--road` | one plan by number or by file (its project found from the registry), or only the question *can this seat reach the board?* |
| the plan tools | `plan.sh new`, `note.sh` and `home-sync.sh ship` call `plan-card-after.sh`, which checks the road in the foreground and syncs that plan's card in the background. A seat with no road, or a plan whose project has no board, says so by name |
| the report | after a full run: the count per place (plans in the ledger against plan cards on the board), every plan it could not sync and why, every diagram the board could not draw |

Ymir still holds no board engine. Markup and diagrams are the board's to make: the contract only says *this description
is Markdown*.

## Proof

`python3 -m unittest tests/test_plan_sync.py` — 8 tests: whole cards with sub-items, a second run with zero writes, a
status flip, a short card upgraded in place, a file naming its own project, the road refused by name, the after-hook
saying what it did, and a board that cannot page refused. The live run on the operator's board is in the errand's report.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #851

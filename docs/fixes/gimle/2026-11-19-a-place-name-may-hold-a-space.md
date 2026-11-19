# A place whose name held a space could not be granted

**Component:** `gimle` (the MCP door's token file reader, `bin/gimle/mcp/gimle-mcp.py`).
**Date:** 2026-11-19. **Plan:** plan 149, item 5.

## What was wrong

The token file reader split each line on whitespace. A place named `acme/Field Notes` became the place
`acme/Field` and a fleet called `Notes`. On the night the plan was written, a real grant had to shrink because
its place could not be written down at all.

## What was changed

One reader, `State.parse_token_line`, now serves both `token_rows` and `tokens_map`:

- the place column is everything after the subject, split on **commas only**, each name trimmed;
- the column may be quoted (`"acme/Field Notes,Ymir"`) or run bare to the end of the line;
- the fleet is named by a trailing `fleet=<name>`;
- blank lines and `#` comment lines are skipped.

A bare fourth word is now part of the place column rather than a fleet. That is never silent: a place that
resolves to nothing is named in `who_am_i`'s `unresolved_places`.

## How it was proved

- `test_oauth_door.py` test 3: a line carrying `"acme/Field Notes,Ymir" fleet=guest-house` is granted
  exactly `["acme/Field Notes", "Ymir"]`, and its ledger line carries the fleet.
- On the heart, every one of the 10 lines in the live token file reads the same subject, places and fleet
  under the new reader as under the old one (`token lines read identically: 10, differing: 0`). No live line
  used a fourth field.

## CHANGE LOG

- 2026-11-19 — review-mend: added missing heading for #826

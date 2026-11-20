# 2026-11-20 — the board's token road asks the harness's headers helper

**Component:** records (`bin/boards/board_adapter_mcp.py`).

**Plan:** 335 — plans on the board, item 5 (the plan tools sync a card on any seat, through the seat's own token road).

## What was wrong

A `board:` block names its token by reference, for example `token_from: claude-mcp:<server>`. That reference read only
a **fixed** `Authorization` header from the harness's MCP entry. An enrolled seat no longer keeps one: its entry names a
`headersHelper`, a command that prints the header from a private token file.

So on such a seat plan-sync said *"no road to the board — the token named by 'claude-mcp:…' is not there"*, while the
harness itself reached the same board without trouble.

## What changed

- A `claude-mcp:` reference with no fixed header now runs the entry's `headersHelper`, exactly as the harness does, and
  reads `Authorization` from the JSON it prints. The value is never printed or stored.
- Writes are paced at 2.5 seconds by default (`YMIR_BOARD_PACE`). A board's API may allow about 60 calls a minute, and
  the whole house shares that key, so a run of hundreds of writes must not starve everyone else.
- A page cut short through the tunnel (`IncompleteRead`) and a tunnel blink (`HTTP 520`–`530`) are retried like any
  other hiccup. Both were measured on the first dry run of a 702-item place.

## Proof

On the dev seat: `resolve_token('claude-mcp:<server>', …)` returned a token (its length only was checked), and a dry run
of the Gimlé ledger listed its place in full through it.

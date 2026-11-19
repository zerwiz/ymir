# No UI window per MCP call — seated by install and by update

**Component:** `bridge` (`bin/bridge/mcp-config-seat.py`), with a step added to Gróa's update
(`bin/agents/groa-update.sh`). **Date:** 2026-11-19. **Plan:** the operator's plan 324, row F11.

## What was wrong

pi's MCP adapter opens a viewer window for every tool call unless the server's entry says
`openUi: false`. In a browser, that means a new tab per call. The fix was first made by hand on one
machine, in its two pi config files. Any other seat, or a fresh install, still opened a tab per call.

## What was changed

- The pi seat writes `openUi: false` on every server it seats. That covers the record doors and every
  server in pi's own set. A server where the operator set `openUi: true` keeps it, because the switch
  is per server on purpose. The other harnesses' formats are unchanged; they do not read the key.
- Install already ran `bin/bridge/mcp-config.sh seat` in its memory step. Gróa's update now runs it as
  its own step (`mcp-seat`), so the setting arrives on update and not only at first install.

## How it was proved

- `bin/gates/tests/test_mcp_seat_quiet_ui.sh` (fenced: HOME, the source and the pin are temporary)
  passes. A fresh seat writes `openUi: false` on `board`, `tools`, `well`, `bolthorn`, `skuld` and
  `firecrawl` in both files, and keeps `viewer` at `openUi: true`.
- On this machine, `mcp-config-seat.py … pi --dry-run` against the hand-fixed files proposes no
  `openUi` change. The seat now writes exactly what the hand wrote.

## Limits

A window the adapter already opened is browser-side. Closing it is a person's hand. The setting takes
hold at the adapter's next connection.

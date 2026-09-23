# runtime · 2026-09-23 — Skuld, the ticket hall (:8320)

## Why
Work crosses the fleet as errands/plans/rulings, but the visible ledger — the
tickets a user sees — did not exist. Plan 43; the wayofteams MCP audited (their
remote JWT + namespace tickets); ours is in the package, served from the heart.

## The blocking law (the Allfather's decree)
An agent that does not make tickets and plans correctly is BLOCKED. The shape's
law (the store enforces it): a registered namespace; ticket title 4+ /
description 10+ / valid priority / <= 6 labels; plan body 40+ and its
tickets[] must all exist in the namespace; statuses walk forward
open -> in-progress -> review -> closed (closed terminal). A violation is
recorded on the blocks ledger; at SKULD_TOLERANCE (default 1) the agent is
hard-blocked (every skuld tool refuses) until the operator clears
(blocks/clear, open only to SKULD_OPERATOR).

## What
- `tools/tickets-mcp/server.mjs` — deps-free stdio MCP (psql against the
  heart's postgres `skuld` db; the skuld role): tickets/create, tickets/list,
  tickets/get, tickets/update, tickets/close, plans/create, plans/list,
  blocks/status, blocks/clear; resources `skuld://book`.
- `tools/mill/systemd/skuld.service` — the %h-native unit, mcp-proxy on :8320.
- `bin/fleet-ensure.sh` — raises skuld, mirrors the server, and writes the
  `skuld` MCP door beside well/bolthorn in the seat's pi mcp.json.
- Store: `skuld` database (tickets · plans · blocks · namespaces) with the
  skuld role's grants; seeded namespaces: ymir, whynotproductions.

## Files
- `tools/tickets-mcp/server.mjs` · `tools/mill/systemd/skuld.service`
- `bin/fleet-ensure.sh`

# Canvas writes escaped the read-only door

**Component:** `gimle` (the MCP door, `bin/gimle/mcp/gimle-mcp.py`).
**Date:** 2026-11-19. **Plan:** plan 149, item 4.

## What was wrong

The door's phase (`--allow-write`) gated the board's writes in `plane_tools.py`, but the canvas verbs went
straight to the board agent. On a door started read-only, any static token could still call `add_elements`,
`update_elements`, `save_room` and `share_room`. A read-only door that lets a token draw, save and share is
not read-only.

## What was changed

`CANVAS_WRITES` names the four verbs, and `call_tool` refuses them before the board agent is asked whenever
the caller may not write. The refusal names which half said no: the door (`this door is read-only — the unit
must be started with --allow-write`) or the caller's grant (`an OAuth login needs the gimle-write group`).
The handler logs it with the reason, as every refusal is logged.

The per-caller rule lives in one object, `CallerView`. A static token writes when the door allows writing,
as before. An OAuth caller writes only when the door allows it and their groups carry `gimle-write`.

`snapshot` and `focus` are left outside the gate, as the plan names four verbs. `snapshot` persists a room's
current scene without changing it; `focus` is a viewport hint.

## How it was proved

- `test_oauth_door.py` test 7: a static token on a read-only door is refused on all four canvas writes, and
  four `refused` ledger lines carry `read-only` in their reason. Test 6: an OAuth login without
  `gimle-write` is refused on a writable door, and a login with it passes the gate.
- On the heart, the new door on a spare read-only port refused `save_room` for a real static token, and the
  ledger line read `bearer-file save_room refused save_room writes, and this door is read-only`.

## CHANGE LOG

- 2026-11-19 — review-mend: added missing heading for #826

# Every Ymir MCP tool names the figure who answers for it, and the calendar tool works again

## What was wrong

- 32 of the 44 tools of `bin/mcp/ymir-mcp.py` named no figure, so nobody answered for them in the naming law.
- `ymir_calendar` called `bin/time/snotra/calendar-ask.sh`, a file that does not exist since the move of plan 129.
  The tool could only fail. Skírnir's `schedule_now` (`systems/skirnir/services/skirnir.py`) called the same missing
  path and always answered "no calendar door on this seat".

## What changed

- Each tool's description now begins with its owner (`Reginn — …`, `Mímir — …`), after plan 374's table. No tool is
  renamed: the names are a contract every harness depends on.
- `ymir_calendar` and Skírnir's `schedule_now` call Mánagandr's door, `bin/time/managandr/calendar-ask.sh`, which
  execs the engine in `systems/snotra/services/calendar/`.

## Proof

- `python3 bin/mcp/ymir-mcp.py --selftest` → `doors: 44`, `prompts: 25`.
- `python3 bin/mcp/tests/test_figures.py` → `ok: 0 failed`.
- `bash bin/time/managandr/calendar-ask.sh probe` → `"status": "ok"`.

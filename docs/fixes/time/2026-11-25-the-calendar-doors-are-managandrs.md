# The calendar doors are Mánagandr's: bin/time/managandr/ (plan 374 A6)

The calendar is Mánagandr's, but its one door at `bin/time/` sat in Snotra's folder (`bin/time/snotra/calendar-write.sh`),
and the read door the MCP and Skírnir called (`bin/time/snotra/calendar-ask.sh`) did not exist at all.

- `bin/time/managandr/calendar-write.sh` — moved with `git mv` from `bin/time/snotra/`; it execs
  `systems/snotra/services/calendar/calendar-write.sh` as before.
- `bin/time/managandr/calendar-ask.sh` — new; it execs `systems/snotra/services/calendar/calendar-ask.sh`.
- `bin/time/snotra/calendar-write.sh` — now a forwarding stub to Mánagandr's door, for one release cycle.
- Callers repointed: `ymir_calendar`, Skírnir's `schedule_now`, and the voice tools `read_calendar` and the write tool.

Moving the calendar engine itself out of `systems/snotra/services/calendar/` is a later errand; until then every caller
reaches it through Mánagandr's door, so that move will change one line.

## Proof

- `bash bin/time/managandr/calendar-ask.sh probe` → `"status": "ok"`.
- `bash bin/gates/guards/path-ledger-guard.sh check` → clean.

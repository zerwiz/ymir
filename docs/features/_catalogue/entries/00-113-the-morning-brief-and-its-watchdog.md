---
section: core-install-run-operate
---
| Operate | **The morning brief, and what to do when it is not clean** (`bin/time/nornir-job-daily-briefing.sh` · `bin/time/nornir-job-brief-watch.sh`) | The 07:00 brief writes the day from records, never from memory, and publishes the file *before* it exits non-zero over an aged letter — so one bad morning reads as a missing document. A second row at 07:05 judges the morning: did the brief fire and with what code, does the file exist, and what does the brief's own `drafts:` line say — then sends exactly ONE line, the reason in plain words and one drafted next act (aged drafts are send-or-discard · a missing drafts door means the pin is stale, run `pin-refresh` · a refused grant · a row that never fired means the scheduler is down). A clean day is silent and records its no-op. Migration `0025-brief-watch-row` seats the row on existing homes. Proved by `bin/time/tests/test_brief_watch.sh` | [docs/features/the-morning-brief.md](docs/features/the-morning-brief.md) |

## CHANGE LOG

- 2026-11-18 — review-mend: added missing heading for #817

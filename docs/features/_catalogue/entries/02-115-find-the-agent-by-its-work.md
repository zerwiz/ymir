---
section: agents-work-collaboration
---
| Collaboration | **Find the agent by its work — `seat-find`** (`bin/seat/seat-find.sh` · [how-to](docs/features/find-the-agent-by-its-work.md)) | Plan 293 part 6, from the day the helm briefed the wrong worker because its tab title looked right. It reads the recent screen of every pane that carries an agent, matches your words **literally** (every word by default, `--any` for one, case ignored) and prints pane, agent, status, the matched words, the last matching line and the title. **Your own pane is skipped** (the words you search for are usually in your own scrollback) and it says so; `--all` includes it. A pane that cannot be read is named and counted, so "no match" is never the same answer as "could not look". Proved by `bin/seat/tests/test_seat_find.sh` (13) | [docs/features/find-the-agent-by-its-work.md](docs/features/find-the-agent-by-its-work.md) |

## CHANGE LOG

- 2026-11-14 — added with the door (plan 293 part 6).

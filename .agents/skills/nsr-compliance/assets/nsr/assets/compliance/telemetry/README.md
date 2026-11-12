# telemetry/ — __PROJECT__

Observability & cost tracking.

## Files
- `logger.py` — SQLite logger: writes `runs`/`events` to `runs.db`.
- `runs.db` — generated local store (git-ignored).

## Rules
- Every run logs tokens, latency, tool calls, cost.
- One data path: agents write to SQLite; readers poll SQLite (`logger.py query`).

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.

# telemetry/ — __PROJECT__

Observability & cost tracking.

## Files
- `logger.py` — SQLite logger: writes `runs`/`events` to `runs.db`.
- `runs.db` — generated local store (git-ignored).

## Rules
- Every run logs tokens, latency, tool calls, cost.
- One data path: agents write to SQLite; readers poll SQLite (`logger.py query`).
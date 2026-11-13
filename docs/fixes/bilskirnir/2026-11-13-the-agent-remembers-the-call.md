# Bilskirnir: the agent remembers the call, and the settings panel opens at once

**Status:** built and tested on heimdall and nidavellir, 2026-11-13 (plan 275).

## What changed

| Seen | Fix | Proven (heimdall) |
|---|---|---|
| A call's words never reached the agent's own memory; the call summary was written by xAI's model, which needs a key the house does not have | On the house voice road, at hang-up the call's lines are handed to the agent's own Hermes conversation (no visible line of his is added), and the agent answers with a one-line summary in its own model | 33 s after hang-up, deepseek answered "Noted: Aegir invoices are in the blue folder on your desk — logged to today's daily record"; a written question 3 s later was answered "In the blue folder on your desk." |
| The engine panel showed "Looking…" for about 20 s each time it opened | The provider catalog is kept, handed out at once, refreshed in the background after a minute, warmed at start and dropped when a provider is added or removed | `GET /api/models` answered in 10 ms and 7 ms |

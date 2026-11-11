# Fix — the session digest shows the day's newest work, not its oldest

**What was wrong.** The session-start digest printed today's log with `head -24`. The log grows downwards, so a session
opened in the evening saw only the morning: on 2026-11-11 the log had 78 lines and the night's work sat on lines 63–78,
never shown. The operator asked: *"why don't the agents update the saga?"* — they had; Sága only read the top.

**What was done.** `bin/time/saga-session-start.sh` now prints the **last 40 lines** of today's log, and first says how
many earlier lines there are (`daily-log.sh today` shows them all).

**How it is proven.** On 2026-11-11's log (78 lines) the digest's TODAY section begins "(38 earlier lines today …)" and
carries the "Night" section and the plan-253 line.

## CHANGE LOG

- **2026-11-11** — written with the change.

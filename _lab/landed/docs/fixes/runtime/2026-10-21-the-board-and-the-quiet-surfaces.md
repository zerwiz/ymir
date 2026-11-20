# The board's due dates, the cron that failed silently, and four surfaces nobody watched

**Component:** runtime · **Seat:** heimdall · **Date:** 2026-10-21

## What the Allfather noticed

*"we have also passed some of the tasks' time in trello … and no notifications about that at all."*
He was right, and the audit said why: **nothing in Ymir read a Trello due date.** The digest counts
overdue *actions in the meeting record*; the board is a different surface, and it had no watcher.

## What now exists

- **`bin/time/snotra/trello-due.sh`** — reads the board (the same OAuth grant the export uses),
  skips cards that are closed or complete, and says **one line per bucket per day**: overdue is a
  HIGH naming the worst card and its age; due today is a MEDIUM. Scheduled at **07:45**.
  Its first real run found exactly what he saw: **1 overdue ("Road map & Trello — 2026-10-20") and
  5 due today** on *Synteon — Meetings*. The board is resolved by exact name, then by substring —
  because "Meetings" was renamed to "Synteon — Meetings" and a silent miss is the failure mode.
- **Cron failure reporting** — the scheduler now captures each job's exit code and, on a non-zero,
  sends a **HIGH** through Hófvarpnir with the last line of output, keyed per job per day. Both
  execution branches (flock and fallback) are wired. A failed job is no longer a log line.
- **`bin/time/housewatch.sh`** + a fifteen-minute timer — four surfaces that fail silently: the
  model rail (`:8080`, with its key), the MCP gateway (`:8316`), the well bridge (`:4602`), and
  **the hound's own heartbeat** (a silent guardian is a CRITICAL). Keyed per surface per hour.

## Proved

```
housewatch{surface,state,note}:
  "rail","ok","answers"
  "mcp-gateway","ok","listening on :8316"
  "well","ok","the bridge answers on :4602"
  "hound","ok","heartbeat 0s old"
housewatch{checked,failed}:"4","0"
```

and, on the board:

```
trello-due[1]{board,overdue,due_today,worst}:
  "Synteon — Meetings","1","5","Road map & Trello — 2026-10-20"
```

## What is still owed (plan 100)

Sign-off replies, the rail/well/MCP checks are done, but the **remaining event wiring** — a sign-off
answer reaching the door, a blocked plan item announcing itself — is H8 in plan 100 and named there
rather than implied here.

# The daily line writes itself — the second broken link, closed

**Date:** 2026-11-01 · **Component:** agents · **Status:** door landed; today's log carries its first generated line

## The fault

The documentation design counts every kind of page and names two broken links. The handoff was closed hours
ago (`bin/agents/report.sh`). This is the second: **fourteen daily logs existed and the newest was six days
old** — the Nornir briefing ran every morning, but nothing wrote the *day* from the record, so a week of
measurement lived only in a conversation.

## What landed

`bin/time/daily-line.sh` — the day's line, generated from two sources and nothing else:

- **the handoffs written today** — every report on `state/eindri-reports/` whose dated section is today,
  with its state, its next step, and its *unproven* line if it has one;
- **the cards**, when the seat has a board (`PLANE_API_BASE` + a vault token): how many carry
  `blocked:<who>`, and which ones.

A seat with no board writes the handoff half and **says so** — `cards: 0 — no board on this seat` — a clean
skip, never a silent zero (RULES/25).

It appends through the one daily door (`bin/records/daily-log.sh add --actor nornir --tag daily-line`), so
the log keeps one shape and one writer. `--dry-run` prints it; `--date` replays a day.

A cron row at `@dev 18:00` closes the day; the 07:00 briefing stays as the morning read.

## Proof

```
$ bin/time/daily-line.sh --dry-run
daily line
cards: 0 blocked
handoffs today: 1
  · ses-2026-11-01 — done; next: import growth-agent into Gimlé the same way investready was read and filed
    unproven: the fix to the browser kill is unproven until a signed death; the outbound-gate suite is still red (8 fail)
```

and the real run appended it to `hodd/memory/daily/2026-11-01.md` under `## 22:15 — nornir`.

## Owed

- The board half counts only `blocked:` today. It should also count *closed today* and *in progress*, which
  needs the state ids rather than their names — a small extension once the first cycle exists.
- The gate that refuses to close an errand without a handoff is still owed; the door now exists for it.

# Sixteen of twenty events reached nobody — now there is one door

**Component:** runtime · **Seat:** heimdall · **Date:** 2026-10-21

## The audit that started it

Of 70 catalogued features, **one family** (errands) could reach the live session. Four shelves
(`bin/engine`, `bin/fleet`, `bin/records`, `bin/bridge`) could not speak at all, and of twenty events
that matter — a cron failing, a Trello card going overdue, a sign-off reply, the rail down, the well
behind, a plan blocked on the operator — **sixteen spoke to nobody, or to a popup nobody reads.**

## What was built

- **`bin/notify/send.sh` — Hófvarpnir** (Gná's horse: every rider sends by the same mount): Runes always; a wake into `.wake-queue` at MEDIUM; the
  desktop at MEDIUM (quiet hours suppress MEDIUM at night, never CRITICAL); the pocket at HIGH; and
  **Telegram at HIGH or `--ask` through the Bot API**, which is the away path because it needs no
  session. Dedupe by `--key` (one hour), collapse above eight events an hour per source, and exit 1
  rather than silently deliver to nobody.
- **`bin/time/calendar-watch.sh`** + `calendar-watch.timer` (five minutes) — a reminder at fifteen
  minutes (MEDIUM) and five (HIGH), keyed `cal:<event>:<window>` so polling cannot nag.
- **Garmr and the inbox watcher moved onto the door** — their private spouts are now one call, so a
  hound CRITICAL reaches the session it protects, not only a popup and a phone.
- **Docs**: two feature pages and two `FEATURES.md` rows (Rule 14/27).

## Proved, on the first real message

```
notify[1]{decision,source,severity,rune,arm,desktop,pocket,telegram}:
  "send","test","HIGH","1","1","1","1","1"
```

**All five legs answered** — the Rune, the wake queue, the desktop, the pocket (ntfy, configured this
afternoon) and Telegram (paired this evening). The same call twice with the same `--key` produces a
`duplicate` and a Rune saying so, which is the behaviour a five-minute timer depends on.

# Rödd's hands — the voice reaches the house

## What it is

Rödd is the voice. It could talk, but it could not *do* the things you ask it to do: hand a line to the
session that holds the arm, list or speak to a worker in herdr, reach a seat in Sessrúmnir, or make and move
a meeting in your calendar. Six hands close that, and each one refuses in words rather than reporting
something it did not do.

## What you need

Nothing extra for the arm and herdr. The seat wire needs Sessrúmnir's headless shell running; the calendar
needs a Google grant that carries `calendar.events` (write), which the current grant does **not** — that is
the refusal you will see first, and it is the honest answer.

## Do it

Ask Rödd out loud. Behind the words, these are the six doors:

```
bin/voice/rodd-arm.sh who                 who is holding the arm
bin/voice/rodd-arm.sh tell "one line"     hand a line to that session
bin/seat/herdr-agents.py                  every worker standing in herdr
bin/agents/eindri-send.sh <pane> "line"   one line to a worker (then read its pane)
bin/seat/sessrumnir-wire.sh seats         the seats Sessrúmnir holds, with their state
bin/seat/sessrumnir-wire.sh send <seat> "one line"
bin/seat/sessrumnir-wire.sh read <seat>   the last answer that seat gave
systems/snotra/services/calendar/calendar-write.sh scopes
systems/snotra/services/calendar/calendar-write.sh create --title "a meeting" --when 2026-11-10T14:00:00
systems/snotra/services/calendar/calendar-write.sh move <event-id> --to 2026-11-11T10:00:00
```

## Notes & limits

- **The calendar refuses until the grant carries `calendar.events`.** Measured on this seat: it does not. The
  refusal names the scope and the one command that re-mints the grant (`bin/mail/connect.sh google`).
- `create` is handed to the one write door (`calendar-invite.sh`), so the approval that binds your word to
  the exact invitation is unchanged. `move` reports the **old** time beside the new one.
- A move mails nobody (`sendUpdates=none`) unless you say `--notify`, and `--notify` needs your word.
- The seat wire reaches Sessrúmnir's **headless web shell** (`:3890`), not the desktop window; when the shell
  is down the wire says so and names the command that raises it.
- The verbal rule still holds: no worker is sent out on a spoken word alone, and nothing here merges or
  sends mail.

## If it does not work

- `no shell` — raise it: `apps/sessrumnir/bin/sessrumnir-web.sh start`.
- `Nobody is armed` — no session is draining wakes; the line went nowhere and the answer says so.
- `herdr did not answer` — herdr is not running in this terminal; the list is never invented.
- `no seat named …` — run `seats` first; the wire will not guess which seat you meant.

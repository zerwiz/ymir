# Make and move a meeting

> Mánagandr reads your calendar, and stays read-only. `calendar-write.sh` is the hand: it makes a
> meeting and moves one, in your own Google Calendar — or it refuses, naming the scope it lacks.
> There is no local calendar to fall back on.

## What it is

One write door for the calendar, built for a spoken request ("move my eleven o'clock to two"). It
resolves the grant the **connect door** wrote (`SNOTRA_GOOGLE_REFRESH_TOKEN`, read through the
vault), proves that grant carries Google's write scope `calendar.events`, and then calls the
Calendar API.

`move` finds the meeting by its id or by its title words. If the words match more than one meeting
it **refuses and lists them** — a wrong meeting moved is worse than a question.

## What you need

- the Google grant: `bin/mail/connect.sh google` (which asks for `calendar.events`), or
  `CALENDAR_WRITE=1 systems/snotra/services/calendar/calendar-auth.sh --store`;
- a when you can say plainly: `2026-11-12 14:00`, `2026-11-12T14:00:00+01:00`, `tomorrow 09:30`,
  `monday 10:00`, or just `14:00`.

## The commands

```sh
C=systems/snotra/services/calendar/calendar-write.sh
$C status                                      # ready · read-only · unmeasured
$C create --title "Example4 review" --when "tomorrow 09:30" --duration 45m
$C create --title "Review" --when "2030-01-02 09:00" \
    --attendees a@example.com --dry-run        # say what would happen, change nothing
$C move "Standup" --to "tomorrow 14:00" --duration 30m
$C move ev-1234abcd --to "2026-11-12 16:00"
```

The `bin/` front for it is `bin/time/snotra/calendar-write.sh`, which execs the door above and  # allow-superseded-path: the bin/ shim RECORDS the move and execs the system door
prints the move notice, exactly as the other retired shims on that shelf do.

## Limits — what it will not do

- **It will not write without `calendar.events`.** A read-only grant is refused, with the scope
  named and the two commands that re-consent. Exit code 3.
- **It never writes to a local calendar.** A write that does not reach Google is a failure that
  says so; a meeting that exists only in a file is a lie.
- **`move` mails nobody** — it sends `sendUpdates=none` and says so, because moving a meeting is an
  edit. An invitation is `create`'s job, and that goes through the approval gate: an event with
  attendees posts without mailing anyone until your word is standing and fresh.
- If the scope cannot be measured (the tokeninfo door is down), the door tries the write and
  Google's own `403 insufficientPermissions` becomes the same named refusal.

## If it does not work

`calendar-write.sh status` says which of the three states you are in. `read-only` means the grant
is live but cannot write — re-consent once. `unready` means the vault key or the client is missing.
`--dry-run` on any verb prints the exact instant and payload without posting anything.

The proofs (offline, against a local fixture, nothing sent to Google):
`bash systems/snotra/services/calendar/tests/test_calendar_write.sh`.

## Files

`systems/snotra/services/calendar/calendar-write.sh` · `calendar-grant.sh` ·
`calendar-invite.sh` (the invitation door, and the outbound-mail gate) · `tools/calendar/reader.mjs`
(the read side, unchanged and still read-only).

## CHANGE LOG

- **2026-11-09** — written with the door it describes (plan 231 R2): `create` · `move` ·
  `status`, the shared grant library, and the scope refusal that names `calendar.events`.

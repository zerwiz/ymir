# The calendar watch — do not walk into a meeting by accident

**What it is.** `bin/time/calendar-watch.sh` reads the calendar through Mánagandr and, when an event
is about to start, says so through Hófvarpnir (`bin/notify/send.sh`).

**What you need.** The Google Calendar grant in the vault (the same one `calendar-ask.sh` uses).

**The commands**

```sh
bin/time/calendar-watch.sh                 # the five-minute run (a systemd timer calls this)
bin/time/calendar-watch.sh --lead 30       # remind earlier
bin/time/calendar-watch.sh --dry-run
```

**The schedule.** `calendar-watch.timer` runs it every five minutes. Two reminders per event: one at
fifteen minutes (MEDIUM) and one at five (HIGH, so it reaches the phone and Telegram).

**Why it cannot nag.** Each reminder is keyed `cal:<event-id>:<window>`, so the hotline's dedupe
means five-minute polling produces one reminder per window, not twelve. All-day and cancelled events
are skipped.

**What it does not decide.** Whether you attend. It says a meeting is starting; you say what to do
about it.

**If it does not work.** `bin/time/snotra/calendar-ask.sh probe` — if the grant has lapsed, the
probe says so. `--dry-run` on the watcher shows what it would have said.

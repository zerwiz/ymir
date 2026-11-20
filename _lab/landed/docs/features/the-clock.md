# The clock — one time, one answer

> **Status: built and tested (2026-10-18).** `bin/time/sol.sh` (**Sól**, the sun's wheel),
> wired into the Sága session digest, tested by `.agents/tests/sol-clock.test.sh` (21 checks,
> including both daylight-saving boundaries).

## What it is

Every agent needs to know the time, and each one was reaching for `date` with different flags,
different zones and different formats — and arithmetic across a daylight-saving boundary is
where hand-rolled answers go quietly wrong. **Sól is the one door.**

It answers three questions and refuses to guess:

1. **What time is it?** — local with its offset, UTC, epoch, the zone *and where that zone came
   from*, the ISO week, the day of the year, and whether DST is in effect.
2. **What time will it be / was it?** — `add`, correct across DST because the arithmetic is done
   on the *instant*, not on the wall clock.
3. **How far apart are two times?** — `diff`, reporting **both** the elapsed distance and what a
   calendar shows, because across a DST boundary they differ and only one of them is real time.

## The commands

```sh
bin/time/sol.sh now                     # the full picture (default)
bin/time/sol.sh iso                     # 2026-10-18T17:55:04+03:00
bin/time/sol.sh utc                     # 2026-10-18T14:55:04Z
bin/time/sol.sh epoch                   # 1792335304
bin/time/sol.sh stamp                   # 20261018-145504Z   (sortable, filenames)
bin/time/sol.sh tz                      # Europe/Helsinki, and that it came from the machine
bin/time/sol.sh add +1d -2h             # move from now — DST-correct
bin/time/sol.sh diff <a> <b>            # elapsed + calendar distance
bin/time/sol.sh context                 # the block an agent reads at session start
bin/time/sol.sh check                   # is this clock sane? NTP state, zone, offset
```

Flags: `--at <ISO|epoch>` (a fixed “now” — how it is tested), `--tz <zone>`, `--plain` (one value,
for a shell variable).

## What you need

Nothing beyond the repo: `python3` (standard library `zoneinfo`) and GNU `coreutils`. The tool is
read-only — it never sets the clock.

## The zone

The house's zone resolves in one order, and the answer says which one won: `--tz` → `$YMIR_TZ` →
**the machine's own** (`/etc/localtime`) → `$TZ` → UTC. On this machine that is
`Europe/Helsinki`, `source: machine`.

## The daylight-saving truth it keeps

- **`add`** moves on the instant. One day after 2026-10-24 12:00 (+03:00) is **11:00 (+02:00)** —
  24 hours of real time, 23 hours on the calendar.
- **`diff`** reports `seconds`/`human` **elapsed**, and `wall` for what a calendar shows:
  across the spring-forward, `01:00 → 04:00` is **2h elapsed, 3h wall**.
- **A wall-clock time that never existed is normalised**, not echoed: `03:30` on 2026-03-29
  (the skipped hour) comes back as `04:30+03:00`, the real reading at that instant.

## Limits, stated plainly

- It reads the clock; it does not set it, and `check` reports NTP state as the host reports it
  (`timedatectl`) — it does not measure skew against a network source.
- `check` exits **1** when the clock is not synchronised, because every timestamp on this machine
  (Runes, the log, cron) is wrong in that state.
- Zone names come from the system's tz database; an unknown zone is refused, never silently
  replaced with UTC.

## If it does not work

| symptom | cause | do |
|---|---|---|
| `error: cannot read the instant` | a malformed `--at` | ISO-8601 (`2026-10-18T17:55:04+03:00`) or an epoch |
| `error: unknown command` | a typo | `bin/time/sol.sh --help` |
| `check` exits 1 | NTP not synchronised | `systemctl enable --now systemd-timesyncd` |
| the zone is wrong | `--tz`/`$YMIR_TZ` override, or `/etc/localtime` | `bin/time/sol.sh tz` names the source |

# runtime · 2026-09-24 — the role gate parses both orders; the heart's jobs were dead

## Why
The home's `config/cron.yaml` writes its role gate **before** the time —
`@heart 06:00 bin/nornir-job-observer.sh` — while `bin/nornir-cron-start.sh`
parsed the FIRST token as the time (`at=${line%% *}`) and expected any
`@role` AFTER the minute. Every role-first line therefore read "time" =
`@heart`, never matched the clock, and was **silently dead while still counted
declared** — on every seat, the heart's record jobs (observer, briefing,
housekeeping, git-sync, vault sync, forgejo) never fired. Proven live on whynot:
its running scheduler body (pid 34965) predates even the after-time gate, so
only plain `HH:MM cmd` lines could ever have run there.

Second finding: **a running loop embeds its parse at spawn.** The scheduler is
spawned as a background `bash -c` body; the long-lived process keeps the grammar
of the moment it started. A parser fix deployed into the tree does NOT reach the
running loop — the seat needs the pull AND a fresh session (or `--stop` +
start).

## What
- `bin/nornir-cron-start.sh` accepts the `@role[,role]` gate **before** the time
  (`@heart 06:00 cmd`) **or after** it (`06:00 @heart cmd`); the role test
  (`case ",$BROKK_ROLES," in *",$_w,"*`) is unchanged. One grammar for the loop,
  `--status`, and the board's `/api/cron` (same parse, same lines).
- `.agents/tests/cron-role-gate.test.sh` extended: role-first dev/any jobs fire
  on a dev box, role-first `@heart` does not — ALL PASS.

## Verified
- `.agents/tests/cron-role-gate.test.sh` — 7/7 ok (after-time and role-first).
- Live read: a role-first schedule now matches at its minute on a dev box.

## Files
- `bin/nornir-cron-start.sh` · `.agents/tests/cron-role-gate.test.sh`
- `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md`

## Note for the seat
whynot's loop is ALIVE but holds an old body (spawned 2026-09-24 ~09:00, pid
34965). After this merges: on whynot run a pull + restart the loop (a fresh
session or `bin/nornir-cron-start.sh --stop` then start) so the heart's record
jobs fire from the next clock.
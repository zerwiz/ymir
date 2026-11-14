# Every installation is turned off, and told what it used to run

**Date:** 2026-11-14 · **Component:** install · **Doors:** `.agents/migrations/0024-wardens-off-until-named.sh`,
`bin/engine/units.py`, `bin/engine/home-seed.sh`

## What was wrong

The wardens change of earlier the same day (fix note
`docs/fixes/forge/2026-11-14-a-warden-acts-only-where-its-machine-is-named.md`) made an outward warden opt-in
per machine — but only for a machine that had not already been seated. Migration 0023 *recorded* what an
existing installation was doing and left it running. So every machine that installed Ymir before today kept
its outward clocks by inertia: exactly the state that let a collaborator's installation merge pull requests
into this repository under a login this fleet does not own.

The Allfather's word: *"users must get these updates on installations."* A fix that only reaches new installs
is not a fix; it is a new default.

## What changed

`0024-wardens-off-until-named` runs on the update road (`bin/engine/ymir-migrate.sh apply`, called by
`bin/engine/ymir-install.sh` and by `bin/agents/groa-update.sh`) and on a fresh install:

- **no file** → the template is seated, every outward door off;
- every outward door is set **off**, rewriting only a value a *migration* wrote — a line a person wrote is
  left exactly as it is, and that door's timer is not touched;
- `was_on: <date>` is recorded for every door the **old install was actually running**, asked of systemd
  rather than read from the file, because on an old-shaped home there is no file to ask;
- the timer the old install seated is **stopped and disabled**, and its unit file is kept — so naming the
  door and running `systemctl --user enable --now <door>.timer` restores it;
- the outward Nornir jobs (`gna-mail`, `snotra-mail`, `git-sync`, `private-scan`) are turned off the same
  way; a job has no clock, so nothing is stopped.

`bin/engine/units.py` gained `retire_unit`, so every later install and update turns a not-named door's unit
off instead of merely skipping the write — a door that is off can never keep a live clock.

Nothing is deleted, no door is removed, and `merge: on` is never written by a migration.

## The proof

`bin/gates/tests/test_wardens_off_until_named.sh` — 35 cases, CI gate `wardens-off-until-named`. Against a
**copy of an old-shaped home** (seven outward timers running, no wardens.yaml) with `systemctl` stubbed:

| Case | What it shows |
|---|---|
| after the migration | every outward door reads off, and every door refuses |
| `was_on` | recorded seven times, once per clock the old install seated |
| the stub's log | `disable --now` for exactly those seven timers, and no unit that is not an outward warden |
| the stub's state | nothing outward is left running |
| a second run | changes nothing, disables nothing again |
| a door the operator named (`enabled: on`, no migration marker) | still on, and its timer was not stopped |
| a fresh home through `home-seed.sh` | receives the template, every door off |
| the seater afterwards | reports `not-seated`, keeps the unit file |

Measured on this machine for real: seven timers stopped (`inactive` for review-watch, review-seat,
review-loop, pr-watch, issue-watch, ship-watch and queue-warden), 14 unit files still on disk, `was_on`
recorded for the eight doors the old install was running, and `nornir-job-gna-mail.sh` refusing with
`gna-mail.enabled: off` while its read-only `--check` still answers.

## Limits

- A home that has no fleet registry entry and no `YMIR_MACHINE` cannot be named; the migration then defers
  (exit 3) rather than guessing a machine's name — a guess would write a policy into the wrong file.
- The stopping is `systemctl --user`, so on a machine without systemd (Termux, macOS) the migration turns the
  doors off in the file and says the unit could not be stopped; the door's own gate still refuses, so nothing
  acts outward either way.
- Whatever the operator wants back he names back. This machine's restorable list is in
  `$YMIR_HOME/state/eindri-reports/wardens-own-only.md`.

## CHANGE LOG

- 2026-11-14 — written with the change.

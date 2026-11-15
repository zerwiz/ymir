# A warden acts only where its machine is named, only on our repositories, only as the named hand

**Date:** 2026-11-14 · **Component:** forge · **Doors:** `bin/forge/warden-lib.sh`,
`bin/forge/warden-policy.py`, `bin/engine/units.py`, the outward wardens themselves

## What was wrong

On the night of 2026-11-14 every pull request merged into `zerwiz/ymir` — #731–#735, #742, #743, #748 — was
merged by a GitHub account this fleet does not own. Measured at 12:44 CET: heimdall's and the heart's
`queue-warden.timer` were both stopped and disabled, and both machines' `gh` logins were `zerwiz`. The merges
came from outside the fleet — a collaborator's own Ymir install, running the warden this repository ships.

**The fault was ours, and it was in the logic, not in his machine.** A warden was seated by ROLE:
`config/units.yaml` carried `roles: [heart, forge, dev]`, so any machine of those roles got a merging warden
by merely installing Ymir. Nothing asked whether the operator had named that door for that machine, nothing
asked whether the repository was the operator's, nothing compared the GitHub login with the name the machine
gives the duty, and no record said who acted. `bin/forge/pr-watch.sh` even named `zerwiz/ymir` as a default.

## What changed

**One reader, one law.** `bin/forge/warden-policy.py` reads
`$YMIR_HOME/config/machines/<machine>/wardens.yaml`. `bin/forge/warden-lib.sh` is the shared gate every
outward door sources. Five rules, each enforced by code:

1. **Opt-in per machine.** A door runs only where the file says `enabled: on`. Absent is off — a fresh
   install, a collaborator's or a stranger's, seats nothing outward. `bin/engine/units.py` asks the same
   reader (`seat-plan`) before it writes a unit, and every `--install-timer` asks `warden_seat_allowed`.
2. **Own repositories only.** `warden_require_repos` / `warden_require_checkout` read the operator's registry
   (`hodd/identity/projects.yaml`) and refuse any `owner/repo` it does not claim, by name. A registry that
   does not answer claims nothing.
3. **The machine's own identity.** `warden_require_identity` compares `gh api user` with the name the file
   gives that duty and refuses on a mismatch, printing both. An unnamed duty still acts, says so out loud,
   and its Rune carries `identity=<login> names no identity` — never a false claim of matching.
4. **Every outward act is a Rune.** Machine, door, identity, repositories and the verdict it rested on.
5. **A merge needs three yeses.** `merge: on` for the door, the machine the fleet registry names as heart,
   and `bin/forge/merge-verdict.sh` answering yes. Any other answer is a named refusal.

**Gated doors:** `queue-warden`, `review-watch`, `review-seat`, `review-loop` (`review-shelf.sh`),
`pr-watch`, `issue-watch`, `ship-watch`, and the Nornir jobs that reach outward — `gna-mail`,
`snotra-mail`, `git-sync` (push only; fetch is a read), `private-scan`. `gather`, `ship` and `mjollnir` are
a hand's doors: never seated, so never held off, but still gated by repository, identity and record.

**Nothing was removed.** Each door keeps every other law it kept; `ship-watch` still waits for a verdict,
`review-watch` still raises its ask, `gather` still runs the gates once and pushes once.

**The migration.** `.agents/migrations/0023-wardens-per-machine.sh` records what each machine does *today*
as `enabled: on`, so no working timer stops, and adds a missing `enabled:` beside decisions already written.
It starts nothing, stops nothing, and never writes `merge: on`.

## The key is `enabled`, not `on:`

YAML 1.1 — which pyyaml and many other parsers still implement — reads the KEY `on` as the boolean `true`, so
a file saying `on: on` loads as `{True: True}` and every reader sees no policy at all: a switch that silently
unsets itself. The values stay `on`/`off` (this reader normalises booleans either way); the key is `enabled`.

## Proof

`bin/gates/tests/test_warden_lib.sh` — 28 cases, wired into CI as the `wardens-own-only` gate. Against a
fenced home, a fenced unit dir and a stubbed `gh`, it proves: a fresh home seats no outward timer (and both
`--install-timer` paths refuse); a repository outside the registry is refused and named; a mismatched
identity is refused with both names; a named door is seated and works; `merge: on` is refused on any machine
the fleet does not name heart; and the Rune carries machine, door, identity and repository.

Measured on heimdall after the migration (before the pin moved, run from the worktree): `pr-watch --dry-run`
passed the gate and printed the five open PRs with one Rune row; `review-watch --dry-run` raised its asks;
`ship-watch --dry-run` reported "waited for a verdict" and merged nothing; `git-sync` in push mode refused
(`git-sync.enabled: off`).

## Limits

- The identity a duty acts *as* is only as good as the `gh` login on the box: no machine holds a warden
  token yet (plan 290 P5), so a named identity that does not answer is a refusal, and an unnamed one is
  recorded honestly rather than pretended.
- The pin (`~/ymir-runtime`) still runs the old doors until it is flipped; from that moment the gates are
  live for the timers too.
- `bin/time/nornir-job-git-sync.sh` still runs `git add -A` in the home on its push path — a pre-existing
  hazard this change did not touch, named here so it is not lost.

## CHANGE LOG

- 2026-11-14 — written with the change.

## Appended 2026-11-14 — the update road, not only new installs

The Allfather's addition: *"users must get these updates on installations."* Recording what a machine was
doing (migration 0023) left every existing install acting outward by **inertia** — the same inertia that let
a collaborator's install merge here. So the law is applied the other way round, by **migration 0024**
(`.agents/migrations/0024-wardens-off-until-named.sh`), which the update road already runs
(`bin/agents/groa-update.sh` and `bin/engine/ymir-install.sh` both call `bin/engine/ymir-migrate.sh apply`):

- on a home with **no** file, it seats the template — every outward door off;
- it turns every outward door **off**, rewriting only a value a migration wrote (a line a person wrote is
  left exactly as it is, and that door's timer is not touched);
- it records `was_on: <date>` for every door the **old install was actually running** — asked of systemd,
  never of the file, because on an old-shaped home there is no file to ask — so the operator sees what his
  machine used to do and can turn back on what he owns;
- it **stops and disables** every outward warden timer the old install seated, and keeps the unit file, so
  naming the door and `systemctl --user enable --now <door>.timer` restores it;
- and the seater now does the same on every install and update (`bin/engine/units.py`: `retire_unit`), so a
  door that is off can never be left with a live clock by a later run.

`test_wardens_off_until_named.sh` — 35 cases, CI gate `wardens-off-until-named` — proves it on a **copy of
an old-shaped home** with systemd stubbed: seven outward timers running, one file absent; after the migration
every door reads off, `was_on` is recorded seven times, exactly those seven units are disabled and no other
unit is touched, a second run does nothing, a door the operator named is left on with its clock running, and a
fresh install receives the template with every door off. The seater then reports `not-seated` and keeps the
unit file.

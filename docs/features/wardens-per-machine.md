# Wardens per machine — which outward doors this computer is allowed to run

**What it is.** Ymir ships small clocks that act outside the machine: `queue-warden` (queue hygiene and,
on the heart only, merging), `review-watch` and `review-seat` (the review loop), `review-loop`,
`pr-watch` and `issue-watch` (they tell the operator what arrived), `ship-watch` (it ships proved work),
`gather` (it pushes a batch and opens a PR), and four Nornir jobs that read mail or push the record.

Each of those is **off until this machine's own file says on**. The file is

```
$YMIR_HOME/config/machines/<machine>/wardens.yaml
```

and no other machine's file is ever read for this one. A fresh install — yours on a new box, a
collaborator's clone — starts with every door off, because a capability is not a decision to act.

**Why it works this way.** On 2026-11-14 pull requests in this project were merged by a GitHub account this
fleet does not own: a warden this repository ships had been seated by *role* on a machine that merely
installed it, and it acted as whoever happened to be logged in there. The fix is not a switch on the door,
it is a written decision per machine, a repository check, an identity check and a record.

## What you need

- A home (`$YMIR_HOME`) with your project registry at `hodd/identity/projects.yaml`. That registry is what
  says which repositories are **yours**; a door refuses any repository it does not list.
- For the doors that talk to GitHub: `gh` signed in on that machine.
- The machine's name, read from the fleet registry (`hodd/data/fleet.json`) by hostname. Nothing to type.

## Write the file

Copy the template and edit it:

```bash
mkdir -p "$YMIR_HOME/config/machines/$(hostname -s)"
cp ~/ymir/.agents/config/machine-wardens.example.yaml \
   "$YMIR_HOME/config/machines/$(hostname -s)/wardens.yaml"
```

Then name the doors this machine should run:

```yaml
identity: thisbox-warden          # optional machine-wide default

pr-watch:
  enabled: on
issue-watch:
  enabled: on

queue-warden:
  enabled: on
  max_open_prs: 5
  stale_hours: 48
  merge: off                      # only the machine the fleet names as heart may say on
```

The key is `enabled`, never a bare `on:` — YAML reads that key as the boolean `true` and your policy would
silently vanish (the fix note explains it). The values are `on` and `off`.

**Precedence:** the door's own key, then the machine-wide `identity:` / `token_ref:` at the top of the file,
then the door's documented default.

## See what a machine will do

```bash
python3 bin/forge/warden-policy.py doors      # every outward door, on or off, and why
python3 bin/forge/warden-policy.py machine    # this machine, and the machine the fleet calls heart
python3 bin/forge/warden-policy.py repos      # the repositories your registry claims
```

The seater asks the same reader, so a door the file does not name is never written as a unit:

```bash
bin/engine/units.sh write --dry-run | grep not-seated
```

## Starting and stopping a clock

Seating and starting are two different acts. Install and update **seat** what the file names on; they do not
start what the file does not name. To start a door now:

```bash
bin/forge/pr-watch.sh --install-timer     # refuses (exit 3) unless this machine names pr-watch on
systemctl --user enable --now pr-watch.timer
```

To stop one: `systemctl --user disable --now pr-watch.timer`, and set `enabled: off` in the file so the next
install or update does not seat it again.

## Limits

- **Merging lives in one place.** `merge: on` is honoured only on the machine the fleet registry names as
  heart, and only when `bin/forge/merge-verdict.sh` answers yes for that PR. Anywhere else the key is
  refused, and the refusal names the machine the fleet calls heart.
- **An unnamed identity is recorded, not pretended.** Until a machine holds its own warden token
  (plan 290 P5), a door with no `identity:` acts as the ambient `gh` login, says so on every pass, and its
  Rune carries that login. Name an identity and a mismatch becomes a refusal that prints both names.
- **A hand's doors are never held off.** `gather`, `ship` and `mjollnir` are invoked by a person, not a
  clock, so they are gated by repository, identity and record only.

## If it does not work

A door that refuses says which of the three rules refused it, and where the file is:

```
review-watch: REFUSED on heimdall — review-watch.enabled is absent — a door is seated only where the
operator names it (plan 290)
help: name this door in /…/config/machines/heimdall/wardens.yaml (enabled: on) if this machine should run it
```

If `python3 bin/forge/warden-policy.py machine` prints a machine name you did not expect, the hostname does
not match `hodd/data/fleet.json`; set `YMIR_MACHINE` or add the host to the registry.

Every outward act leaves one Rune (machine, door, identity, repositories, verdict), so
`bin/records/runes-append.sh` and the ledger show exactly what ran and on what grounds.

The migration that records what a machine already did is `.agents/migrations/0023-wardens-per-machine.sh`;
`bin/engine/ymir-migrate.sh status` shows whether it has run here.

## CHANGE LOG

- 2026-11-14 — written with the change (plan 290 §3).

## Appended 2026-11-14 — an install you already have

Updates carry this. `bin/agents/groa-update.sh` (and the installer) run `bin/engine/ymir-migrate.sh apply`,
and **migration 0024** turns every outward door off on an existing machine — including stopping and disabling
the timers the old install had seated — and writes `was_on: <date>` beside each door it found running.

`was_on` is a record, not a switch. To give a door back:

```yaml
pr-watch:
  enabled: on          # your decision, beside the record of what the old install did
  was_on: 2026-11-14
```

then

```bash
systemctl --user enable --now pr-watch.timer
```

The unit file was never deleted, so that one command restores it. Nothing acts outward by inertia again: the
seater turns a unit off whenever its door is not named, on every install and every update.

## CHANGE LOG

- 2026-11-14 — appended: the update road turns the doors off and records what was on (`was_on`).

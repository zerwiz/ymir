# The pin was 182 commits behind main — the refresher existed, and the schedule only measured it

**Date:** 2026-11-20 · **Component:** engine (`bin/engine/pin-refresh.sh`, `bin/gates/tests/test_pin_refresh.sh`) ·
**Errand:** `pin-tracks-main`

## What was wrong

At the operator's word: *"The pin must be so its allways latest main. Not old mains for anything. Fix this and
merge it. This must be live for the fleet."*

Measured that afternoon, on the machine that schedules everything:

```
$ git -C <the pin> rev-list --count HEAD..origin/main
182
$ bin/engine/release.sh status
release[1]{current,previous,pin}:
  "<the releases link>","none","<the pin>"
releases:
```

**The refresher already existed.** `bin/engine/pin-refresh.sh` has done exactly the right thing since 2026-11-15:
fetch, fast-forward only, refuse a diverged pin, refuse a local edit git would overwrite, log every move. What it
never had was a schedule.

The schedule had this instead — `bin/time/nornir-job-week-pin.sh`, once a week, whose own header says it well:

> *"So once a week the distance is a NUMBER in a series, not a hope."*

A number in a series is not a pin that follows main. And the refresher **could not be scheduled**, for a reason
its own law states: the scheduler here runs from the pin, and the door refuses to refresh the pin from a copy of
itself — rightly, because a stale copy of the refresher proves nothing.

So the fault was a closed loop: the only thing that could move the pin was a tree that is not the pin, and nothing
outside the pin was ever scheduled to call it.

## What was built

One seam, and one schedule row.

`bin/engine/pin-refresh.sh` gains two flags:

| flag | what it does |
|---|---|
| `--auto-tree` | resolves a tree that is **not** the pin — `YMIR_SOURCE_TREE`, then the source checkout, then a release — and re-execs that tree's copy of the door |
| `--from-tree DIR` | the same, named explicitly; naming the pin itself is refused (`rc 4`) |

The refusal is untouched: the code that moves the pin is never the pin's own possibly-stale copy. What changed is
that a schedule now has a legal road to the door.

The schedule, in the home (`config/cron.yaml`), reads:

```
@heart,forge,dev,hand @every:10 bin/engine/pin-refresh.sh --auto-tree --quiet
```

Every role, every machine, every ten minutes. A machine with no pin at all is a clean skip, not an alarm.

## The proof

Three assertions added to `bin/gates/tests/test_pin_refresh.sh`, and the whole file green:

```
$ bash bin/gates/tests/test_pin_refresh.sh | tail -1
pin-refresh tests: 24 pass, 0 fail
```

Then the real thing, run as the schedule will run it — from inside the pin, with `--auto-tree`:

```
$ cd <the pin> && bin/engine/pin-refresh.sh --auto-tree --quiet
pin: main moved 0ee9c408..ad5ebd34 (+7) — now current
$ git -C <the pin> rev-list --count HEAD..origin/main
0
```

A pin seven commits behind, brought home by one scheduled call, with the move appended to
`<state>/pin-refresh.log`.

## What this does not decide

- **A fast-forward is not a deploy.** A pin at latest main runs main's code in its working-tree shape: no build,
  no proof, one shared dependency tree, no rollback. Plan 333 records the decision to adopt the release road
  (`build → prove → flip`); this row is what keeps the fleet honest until that lands, and the fallback if a
  release ever has to be left behind.
- **Services are not restarted.** A pin that moves under a running process changes what the *next* process runs;
  a running service keeps its old code until it is restarted. That is `release.sh restart`'s business.
- **The weekly measurement job stays.** It is now a witness beside a keeper rather than the only eye on the pin.

## CHANGE LOG

- 2026-11-20 — written the day the pin was found 182 commits behind, with its refresher already written.

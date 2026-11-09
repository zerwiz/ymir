# The switch is one word, and the word stands

**Date:** 2026-11-09 · **Component:** ward · **Door:** `bin/ward/garmr.sh` (`set_switch`, `seat_units`, `status`)

## What was wrong

Garmr could be paused — `bin/ward/garmr.sh pause`, root's marker, the two units stopped — but
the pause was only a **moment**, never a **word**. Four things raised him again while the marker
still said paused:

- a **reboot**: `garmr-arm.service` and `garmr-hound.service` were left `enable`d, so the boot
  raised the hound and its senses with the pause marker sitting right there;
- **`refresh`** (which Gróa runs on every update): `seat_units` re-rendered and ran
  `systemctl enable --now garmr-hound.service` unconditionally;
- **`install`**: same path, same revival;
- **`start`**: the raw unit verb never looked at the marker at all.

And the two readers disagreed about what "off" even meant. `pause` wrote
`/var/log/ymir/garmr/PAUSED`; the tower (`apps/hlidskjalf/server/index.ts`) and
`bin/time/housewatch.sh` read `$YMIR_HOME/hodd/state/garmr/PAUSED`. So a guardian the Allfather
had put down was reported by the tower as neither paused nor silent — a green over a hound that
was not guarding, which is the exact false green this house has paid for twice.

## What was forged

**One switch, two words, one authority.** `sudo bin/ward/garmr.sh off` / `on`. `pause` and
`resume` remain as the same switch under its older names.

`off` writes root's marker and its operator-readable copy (`$YMIR_HOME/hodd/state/garmr/PAUSED`),
appends the turn to `/var/log/ymir/garmr/pause.log`, **stops and disables** `garmr-hound`,
`garmr-arm` and the user's `garmr-brain.timer`, so a reboot cannot raise him. `on` is the exact
reverse and records how long he lay down.

**The copy is a report, never the switch.** `common.is_off()` reads root's marker only; the copy
is read by `common.reports_off()`, `garmr.sh`'s `mode` line and `paused`. That split is the point:
the tower must be able to *say* OFF over a hound it can read, without any file the operator owns
being able to *silence* the guardian — the same invariant the root-only marker exists for.

`seat_units` now asks `is_off` first: while the marker stands it may re-render the unit files but
it never enables or starts them, and it says so out loud. `install` therefore leaves an off hound
off; `refresh` (and so Gróa) cannot revive him; `start` refuses with the word to use instead.
`hound.py` refuses to enter its watching loop while off, so a hand-typed `systemctl start` cannot
quietly begin watching behind the word either.

`status` gained a `mode` line — `ON — watching` or `OFF (since <ts>) — the units are disabled, so
a reboot will not raise him` — and it reads without root, because it falls back to the copy.
`off --dry-run` prints the whole plan without root, so the turn can be understood before it is
made.

**Root is still required, deliberately.** A guardian an ordinary process can silence is a
guardian the intruder silences first. The smoke test now asserts that a non-root `off`, `on` **and**
`pause` are all refused, and that `off --dry-run` still prints.

## What `off` does not do

It does not unload the kernel's audit rules. Those are auditd's, they cost almost nothing, and
forgetting them is how a seat ends up deaf after a quiet week — `off` stops the watching and the
judging, not the kernel's record.

## Verified

```
$ bin/ward/garmr.sh status                    # mode ON — watching
$ bin/ward/garmr.sh off                        # rc=1, "needs root", names the door
$ bin/ward/garmr.sh off --dry-run              # the whole plan, no root
$ bash .agents/tests/garmr.test.sh             # 1 failure, the same "sensitive path" one HEAD has
$ bash bin/ward/garmr-smoke.sh                 # "off guarded" / "on guarded" / "off --dry-run" PASS
```

With the copy present in a scratch home, `status` reports `OFF (since …)`, `brain.py --once` prints
`the hound is PAUSED — nothing judged`, and `hound.py` exits 0 with `the hound is OFF at the
Allfather's word — nothing watched` when **root's** marker stands; with only the copy present the
hound is still gated off nothing (the copy cannot silence him) while the surfaces still report OFF.
Three readers, one authority.

The root half (`off`, `on` against the real units) needs a `sudo` this seat did not have
non-interactively; the plan it prints is the plan it runs.

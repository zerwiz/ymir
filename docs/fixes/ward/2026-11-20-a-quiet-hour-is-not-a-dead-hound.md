# A quiet hour was reported as a dead hound

**Date:** 2026-11-20 · **Component:** ward (`bin/ward/garmr/hound.py`) · **Errand:** `hound-heartbeat` ·
**Plan:** 337

## What was wrong

After a reboot the hound (`garmr-hound.service`) was alive, but its heartbeat stopped a few minutes
after start-up. housewatch then raised `CRITICAL the hound is silent` every 15 minutes. A restart wrote
one heartbeat and went silent again.

The heartbeat was only written inside the findings sink. `main()` called `follow_audit()`, which never
returns, and the sink only ran when an audit group produced a finding. On a quiet box that is rare:
`ymir-exec` records are dropped unless the binary is first-seen, and lines without a `key="ymir-`
are skipped. So the hound was alive and the heartbeat said it was dead.

The listener snapshot had the same fault. It ran in `main()`'s loop between `follow_audit()` calls,
so it ran once at start-up and never again.

## What changed

- A new `Pulse` in `hound.py` holds the heartbeat and the listener snapshot, each on its own clock.
  `follow_audit()` calls it once per tick, whatever the audit log carried (also while the log is
  missing or unreadable).
- The heartbeat is throttled by `hound.heartbeat_seconds` (default 60), now in
  `config/guardian.yaml.example`. The snapshot keeps `poll_seconds` and its de-duplication.
- `follow_audit()` takes `on_tick` and `max_ticks` (the second only for tests). What the hound
  watches did not change.

## The second cause, found on the same machine

The kill findings stopped at 14:35:32, and the auditd journal says why:
`Audit daemon is suspending logging due to no space left on logging partition` at 14:35:35. The root
disk had filled. auditd does not resume by itself when space returns, so the audit log stayed frozen
even after the disk was cleared. The rules themselves were loaded: `garmr-arm.service` ran at boot
and its `auditctl -l | grep -q ymir-exec` check passed.

This fix makes the heartbeat honest about the hound. It does not make auditd write again. That needs
root, and the how-to in `docs/features/the-guardian.md` now names the check and the resume command.

## Proof

`python3 tests/test_garmr_hound_pulse.py` runs the follow loop against a quiet fixture. The heartbeat
mtime advances, the snapshot runs more than once, a missing log still beats, and the heartbeat is
throttled. An end-to-end run of `hound.py` in follow mode against a quiet log wrote a fresh heartbeat
every 2 seconds.

The live service runs as root, so it needs `sudo systemctl restart garmr-hound.service` after the
release carrying this is flipped.

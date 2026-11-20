# The arm could not find its door — and a poll loop that spoke every cycle

**Dated:** 2026-10-24 · **Component:** runtime · **Branch:** `fix/arm-door-and-wake-cadence`
**Found on:** sleipnir (the hand — Termux/Android, Pi 1.4.0, no systemd)

## The symptom

The Allfather's session was flooded: the same line, again and again —

```
RODD_OP: v1 watcher: BROKK WATCHER WAKE: stale: arm service is down - no live lease for
  /data/…/ymir-home/state (remedy: bin/pi/syn-watch.sh start)
```

…over an arm that was measurably **up**: lease valid, `pid` alive, its recorded
starttime matching `/proc/<pid>/stat` to the tick, and `gleipnir_pid_alive` exiting
**0** for the recorded pid and **1** for a planted wrong starttime. Twenty copies of
one falsehood, and silence while the arm was genuinely dead.

## Three faults, one move

**1. The door moved and the engine did not follow.** `src/ymir_runtime/watch.py`
still carried `WATCH_DOOR = ("bin", "syn-watch.sh")`. The 250-door restructure moved
that script to `bin/pi/syn-watch.sh` (`efa6ba34`, `ac5fd8ad`, `7ffc40c7`) and swept
the shell callers — not the Python caller. On a machine **with** systemd the unit
masks this; on the hand there is no systemd, so `start_service` falls through to
"spawn a detached daemon", spawns a file that does not exist, and the arm can never
be seated. `.arm.log` carried five lines of:

```
bash: /data/…/ymir/bin/syn-watch.sh: No such file or directory
```

`syn-watch.sh status` said `"down","none","nosystemd"` while `bin/pi/syn-watch.sh
status` (the same engine, the right door) said the same thing — the truth was
available and unreachable.

**2. The proof could not see it.** `test_watch.py` asserted
`Path(spawned[0][1]).name == "syn-watch.sh"` — a **basename** assertion, blind to
the directory the file sits in. The move that broke the door passed its own test,
and would have passed this mend too.

**3. The arm spoke per cycle, not per transition.** `.wake-last-hash` brakes one
signal per DISTINCT **queue content**; the watcher's `stale:` line was never braked
at all, and `saga-wake-drain.sh` removed the brake hash whenever both doors were
empty — so handling a wake cleared the memory of it. A poll loop that speaks every
cycle is a heartbeat pretending to be an alarm.

## The fix

- `WATCH_DOOR = ("bin", "pi", "syn-watch.sh")` — the engine seats its own daemon
  again, in its own generation.
- `test_watch.py` now asserts the **whole relative tail**
  (`endswith("bin/pi/syn-watch.sh")`) **and** that the door the engine spawns really
  exists on disk (`test_the_door_the_engine_spawns_really_exists`).
- **The cadence law** in `watch.py`: `brake_line()` — the same `stale:`/`check:` line
  may not repeat inside `RAISE_FLOOR_SECONDS` (900), no more than
  `RAISE_HOURLY_CEILING` (3) lines may be raised in one hour, and above the ceiling
  the arm raises **one** line naming its own rate (`check: the arm has raised N lines
  in the last hour`) and then falls silent. The record lives in `.arm.raise`; the
  queue signal is deliberately **not** braked here, because two different queues may
  share the same words and its content hash already makes it one line per change.
- `bin/time/saga-wake-drain.sh` counts with `awk 'END{print NR}'`, not `wc -l`: a
  door judged non-empty by `[ -s ]` must present its lines to the count too (see the
  companion note under `agents/` for the unterminated line that caused the flood).

## Verification

```
PYTHONPATH=src python3 -m unittest src.ymir_runtime.tests.test_watch -q
  Ran 45 tests … OK      (40 before; +5 cadence and door-existence tests)

bin/pi/syn-watch.sh start
  syn-watch: arm seated as a detached daemon for …/ymir-home/state
bin/pi/syn-watch.sh status --detail
  arm=up mode=daemon unit=nosystemd pid=32606 heartbeat=1s session=… 
.arm.log
  syn-watch: arm up pid=32606 gen=2 mode=daemon …      (no "No such file or directory")
```

## Restart

A running `pi` keeps the extension it loaded, and a running daemon keeps the engine
it started. **Close every Pi session started before this branch** (the new extension
and the new door take effect at the next start), then `bin/pi/syn-watch.sh restart`.

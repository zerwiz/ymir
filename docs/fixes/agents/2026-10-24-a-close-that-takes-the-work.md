# A close that takes the work — and a watchdog that proves it armed

**2026-10-24.** Components: `bin/agents/seat-stop.sh` (new), `bin/agents/eindri-control.sh` (`exit`),
`bin/agents/einherjar-spawn.sh` (arming).

## Two faults, one family: a seat's life is not its pane's life

1. **Closing an errand left a worker alive.** On 2026-10-24 a seat was closed while a process waited on
   `state/local-model.lock`; the pane went, the process stayed, and it had to be killed by hand. The same shape
   hid five orphaned scheduler loops inside seat state dirs — found by the smoke suite as
   `cron-leak: 6 cron loops running`.
2. **Arming the silence watch was `|| true`.** So a seat could launch with no watchdog at all and nothing said so.
   Eighteen statuses claimed to be working for up to 719 hours before anyone noticed — because nothing was going
   to.

## The fix

**`bin/agents/seat-stop.sh <id> [--dry-run] [--grace N]`** — stops a seat *whole*, by the only test that does not
lie: **anything whose `cwd` lies inside `.yggdrasil/<id>` belongs to that seat**, whatever it is called — a
harness, an opencode node, a `flock` waiting for the rail, a scheduler. It lists what it found, TERMs, waits the
grace, KILLs survivors, then re-checks and exits non-zero if anything remains.

**`eindri-control.sh exit`** now calls it after closing the pane, and warns loudly if a process survived.

**`einherjar-spawn.sh` arming** now verifies itself: it arms, then asks `eindri-watch.sh list` whether the spec
exists, and records `watch=armed window=…` or `watch=unarmed` in the seat meta. Unarmed prints a `watch[]` line,
writes to meta, and sends one HIGH notification through the notify door — a seat without a watchdog is now a
fact the next reader can see.

## Proof

```
$ bin/agents/seat-stop.sh ledger-bookkeeping --dry-run
seat-stop[1]{seat,worktree,state}:
  "ledger-bookkeeping","…/.yggdrasil/ledger-bookkeeping","present"
processes[7]{pid,cmd}:
  "3060005","pi …"
  "3082959","node …/.yggdrasil/ledger-bookkeeping/.pi/extensions…"
  …
```

## Owed

- The `close` verb of the pi-side errand tool should call `seat-stop.sh` too, so the guarantee lives in the door a
  human uses, not only in the control plane.
- A surviving process after KILL deserves a rune of its own, not only a warning.

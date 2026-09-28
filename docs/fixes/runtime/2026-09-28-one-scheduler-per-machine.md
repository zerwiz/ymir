## runtime · unversioned · 2026-09-28 — one scheduler per machine, and every job carries its role

### Why
- **Five schedulers on one machine ran the same crontab.** The keep-one-loop guard was
  keyed on the **seat's** state dir (`PID_FILE="$STATE/cron.pid"`), so every session that
  started Nornir started its own loop — and each loop read the *machine's*
  `config/cron.yaml`. The smoke test named it plainly: `cron-leak — 5 cron loops running,
  ended seats left schedulers behind`.
- **And the schedule itself was half-ungated.** The role gate was in place for the record
  jobs (`@heart 07:00 bin/nornir-job-daily-briefing.sh`) but the machine jobs carried no
  gate at all — `08:00 hall-snapshot`, `02:30 nsr-compliance`, `00:30 skillopt-sleep`,
  `05:30 bragi-scrape`, `06:45 eindri-handoff sweep`. **An ungated line runs on every
  seat**, so with five seats those five jobs fired **twenty-five times a day** on this box
  alone. The template taught the same mistake: `config/cron.yaml.example` preached
  "a dev body must NOT run the record jobs" and then shipped its own job list ungated.
- **A test that lied.** `.agents/tests/cron-role-gate.test.sh` captured `now` once at the
  top and ran its second fixture ~20s later, so whenever the minute rolled in between, the
  role-first fixture missed and the test blamed the parser for a clock tick.

### Fix
- **`bin/nornir-cron-start.sh` — the loop's identity is the machine's.** A new
  `machine_state_dir()` resolves the machine state the same way the scheduler's own retire
  check does (`BROKK_MACHINE_STATE_DIR` → the `.lock-path` pointer → `$XDG_STATE_HOME/ymir`),
  and the pid file is read and written there. The seat that raises the loop keeps the log
  and the fired-stamps; a second seat reuses the running loop instead of starting a second
  one, and `--stop` from any seat stops the machine's loop.
- **`config/cron.yaml.example` — every job carries its owning role**, with the doctrine
  stated where the list lives: the record to `@heart`, the model work to `@forge`, and the
  supervision sweep to `@dev`, the full body that alone performs it.
- **`.agents/tests/cron-role-gate.test.sh`** recomputes the minute immediately before the
  role-first fixture, with the reason written down.
- **`.agents/tests/cron-one-loop-per-machine.test.sh` (new)** — the regression test for
  the loop.

### Proof
```
.agents/tests/cron-one-loop-per-machine.test.sh
  ok - the first seat starts the loop
  ok - a SECOND seat reuses the machine's loop, starting nothing
  ok - exactly one loop runs for the machine (1)
  ok - --stop from any seat stops the machine's loop
  ok - the machine pid file is cleared
  ok - --status reads stopped after the stop
  -> all cron-one-loop-per-machine tests passed

.agents/tests/cron-role-gate.test.sh   -> ALL PASS (run three times; it flaked before)
```

### The operator's own schedule
`$YMIR_HOME/config/cron.yaml` — the live list — was gated to match, so no line runs on a
body that does not own it. A backup was kept before the edit.

### Not covered here
- **A seat still retires its loop when the machine's session lock dies** — one loop per
  machine, but raised by whichever session is live. A machine with no session runs no
  scheduler, which is the design ("Nornir is started BY a session, never before one").

### Files
- `bin/nornir-cron-start.sh`
- `config/cron.yaml.example`
- `.agents/tests/cron-one-loop-per-machine.test.sh` (new)
- `.agents/tests/cron-role-gate.test.sh`

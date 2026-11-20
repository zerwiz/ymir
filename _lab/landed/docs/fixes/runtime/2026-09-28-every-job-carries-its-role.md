## runtime · unversioned · 2026-09-28 — every job carries its role (and the loop-per-machine defect, recorded not shipped)

### Why
- **The schedule was half-ungated.** The role gate was in place for the record jobs
  (`@heart 07:00 bin/time/nornir-job-daily-briefing.sh`) but the machine jobs carried no gate
  at all — `08:00 hall-snapshot`, `02:30 nsr-compliance`, `00:30 skillopt-sleep`,
  `05:30 bragi-scrape`, `06:45 eindri-handoff sweep`. **An ungated line runs on every
  seat**, so with five seats on this box those five jobs fired **twenty-five times a
  day**, and the same record went off five times over. This is the `cron-leak` the smoke
  test reports (`5 cron loops running`), seen from the other side: even one loop per
  machine would still run an ungated line once per machine that does not own it.
- **The template taught the mistake.** `config/cron.yaml.example` states the doctrine —
  "a dev body must NOT run the record jobs; that is how 8 orphan seat schedulers came to
  run a heart's work" — and then shipped its own job list **ungated**, so every home
  copied from it inherited the fault.
- **A test that lied.** `.agents/tests/cron-role-gate.test.sh` captured `now` once near
  the top of the file and ran its second fixture ~20s later. Whenever the minute rolled
  in between, the role-first fixture missed the schedule and the test failed on a clock
  tick, blaming the parser.

### Fix
- **`config/cron.yaml.example` — every job carries its owning role**, with the doctrine
  restated where the list lives: the record to `@heart`, the model work to `@forge`, and
  the supervision sweep to `@dev`, the full body that alone performs it.
- **`$YMIR_HOME/config/cron.yaml`** (the operator's live list) was gated to match, so no
  line runs on a body that does not own it. A backup was taken before the edit.
- **`.agents/tests/cron-role-gate.test.sh`** recomputes the minute immediately before the
  role-first fixture, with the reason written down. It now passes three runs in a row.

### Proof
```
.agents/tests/cron-role-gate.test.sh   -> ALL PASS (three consecutive runs)
$YMIR_HOME/config/cron.yaml            -> 0 ungated job lines (was 5)
```

### NOT shipped, and why — the loop-per-machine defect
The loop guard is keyed on the **seat's** state dir (`PID_FILE="$STATE/cron.pid"`), so
every session that raises Nornir raises its own scheduler, and each reads the same
machine schedule. Scoping the loop's identity to the machine looks like the right fix and
**a first attempt at it was written, tested and withdrawn in this same change**, because
it could not be proven:

```
a synthetic layout (BROKK_MACHINE_STATE_DIR set, two seat dirs)
    -> 1 loop, seat B reuses it                                              PASSES
the real layout (seats under <machine>/seats/<name>, started as a seat)
    -> seat A starts a loop; seat B starts a SECOND one; no machine pid file   FAILS
       loops after A: 1   loops after B: 2   machine pid: none
```

The trap that made the first attempt look correct: the harness exports
`BROKK_MACHINE_STATE_DIR` pointing at the **current seat**, so the resolver has to
normalise a seat path to its parent before trusting it — and even after that
normalisation the live probe still produced two loops. Shipping a scheduler change on
evidence that contradicts itself is worse than not shipping it, so the revert is
deliberate: **the code is at `16f4108` and the defect stands as the next errand**, with
the probe above as its failing case.

### The next errand, stated for whoever takes it
Make Nornir's loop **the machine's**, not the seat's, with the failing probe in
`.agents/tests/` as the regression: two seat dirs under `<machine>/seats/`, no
`BROKK_MACHINE_STATE_DIR` inherited, started exactly as a seat starts it, and the
assertion that the second start reuses the first loop. Until then, the mitigation is the
one that is verified and shipped here: **gate every job**, so a duplicate loop cannot
duplicate the work.

### Files
- `config/cron.yaml.example`
- `.agents/tests/cron-role-gate.test.sh`

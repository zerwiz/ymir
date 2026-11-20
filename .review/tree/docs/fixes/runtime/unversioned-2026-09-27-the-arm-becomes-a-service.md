## runtime · unversioned · 2026-09-27 — the arm becomes a service

### Why
The supervision arm lived and died with its session. When the session's lock owner went away, the watch loop printed `watcher: retired - session lock is no longer held` and exited 0 — a SILENT close, which the harness reads as "ended without an actionable reason", retries five times, and flaps. On 2026-09-27 it flapped all day and needed three hand re-arms. A session-owned arm is the fault; plan 58 Phase 2 makes the watch a SERVICE that idles instead of dying.

### What
**The watch is a service; the arm script is its thin client** (plan 58, Phase 2).

```
doors[5]{path,shape}
  "bin/syn-watch.sh run","the arm: the poll loop, the heartbeat, the wake raise, the lease — one per home, session-independent"
  "bin/syn-watch.sh status|start|stop|restart","the operator's truth and the raise/lower: up | idle | stale | down, exit non-zero on a gap"
  "bin/syn-watch-arm.sh","the thin client the harness adapters spawn: enter a vacant helm, seat/attach, relay the raised line, exit"
  "tools/mill/systemd/ymir-syn-watch.service","Type=simple, Restart=always + StartLimitIntervalSec=60/StartLimitBurst=10, Environment=BROKK_STATE_OVERRIDE=__YMIR_OPERATOR_STATE__, WantedBy=ymir.target"
  "tests/e2e/arm-service-proof.sh","the plan's gate, runnable: proof (detached) and systemd (Restart=always through a transient unit)"
```

State, all in the resolved state dir:

```
state[5]{file,owns}
  ".watch.heartbeat","epoch seconds — the liveness door the turn-end guard reads (unchanged)"
  ".supervision-armed","the armed marker; written by the arm every cycle, not by the client (unchanged)"
  ".arm.lease","pid + starttime + gen + mode(systemd|daemon) + session(pid|none) + heartbeat + state — lease-based liveness"
  ".arm.event","the ONE raised-but-undelivered actionable line (the delivery slot)"
  ".arm.wake","append-only journal of every line this arm raised"
```

**IDLE-NOT-DEAD.** A dead or absent session owner is recorded in the lease
(`session=<pid|none>`) and the arm keeps standing — the silent `exit 0` retire path
is DELETED. The queue is durable and the session-start digest drains what was
raised while none was seated.

**The extension ABI is unbroken.** The client's CLI is unchanged (`--restart`,
`--handling-delivered <generation> --watcher-pid <pid>`), the grammar is unchanged
(`signal:` / `stale:` / `check:` / `heartbeat:`), and every bin/ door name is stable.
The readiness line is `watcher: started pid=<client-pid> recovery-generation=svc.<arm-pid>.<gen>`
(both the Pi and OpenCode extensions match it as they stand), followed by
`watcher: attached - arm service up ...`. `.pi/**` and `.opencode/**` are untouched;
both harness adapters were read to confirm the contract.

**Seating.** `syn-watch` joins the ONE autoboot table (`bin/autoboot-lib.sh`) as a
heart+dev program, its unit name resolved by `autoboot_unit_of` (door `syn-watch`
→ unit `ymir-syn-watch.service`), materialized by `bin/fleet-ensure.sh` from the
mill template and enabled onto `ymir.target`. `bin/syn-watch.sh start` asks the
SAME renderer (`bin/fleet-ensure.sh unit syn-watch`) — one renderer, so a seat's
unit and the door's unit can never drift — and refuses nothing the fleet's own
`refuse_disposable_path` would refuse.

**A state the one unit does not serve** (a seat's private `BROKK_STATE_OVERRIDE`,
or a probe) gets its own DETACHED daemon: still durable, still leased, still
re-seated by the client — never a second claim on the machine's unit. A unit
instance per seat is Phase 3's seam and is named as such in the asset.

**Loud failure, three ways:** `Restart=always` + `StartLimit` (systemd), the
client re-seating a dead arm inside `BROKK_WATCH_DAEMON_GRACE_SECONDS` (15s) and
printing `stale: arm service is down - ...` when it cannot, and
`bin/syn-watch.sh status` (exit 1) composed by Eir's new `arm` surface.

**Drive-by, same file (named honestly):** `bin/eir-doctor.sh`'s `detail()` branches
were bare command text — a single quoted word, which bash runs as a command NAME —
so EVERY surface row's detail printed empty. They now print the command and the
caller evaluates it; that is what makes the `arm` row actually name the arm
(`arm=idle mode=systemd unit=active pid=… heartbeat=1s session=none`). Row shape and
exit semantics are unchanged.

**Drive-by, the repo's own smoke (named honestly — it was already red on main):**
`.agents/tests/smoke.test.sh` asserted three things the platform no longer does:
the session lock at `$ROOT/state/.lock` (the primary's lock is machine-global since
the one-state-dir change, so it now asks `gleipnir_lock_path`); the watch loop
printing its line in-process (step 5 now runs the client with
`BROKK_WATCH_INLINE=1` — the probe shape — while the standing-service proofs live in
`tests/e2e/arm-service-proof.sh`); and `cron.yaml` inside `.agents/config/`, where
the repo ships `cron.yaml.example` (the live file is the operator's own). All 8
steps pass now.

### The proofs (run, not asserted)
- `tests/e2e/arm-service-proof.sh proof` — **PASS**, 7/7: seats with NO session
  (`session=none`, `status` rc=0); heartbeat age 1s; kill -9 the arm → the standing
  client re-seats it (pid 1434585 → 1436913) and the waiting wake is delivered;
  `status` rc=1 with the arm down; Eir's `arm` row `ok` with the lease named.
- `tests/e2e/arm-service-proof.sh systemd` — **PASS**, 4/4: a transient user unit
  comes active on `ymir.target` shape; `kill -9` the main process and `Restart=always`
  brings it back (pid 1440322 → 1440623, unit still `active`); heartbeat fresh;
  `systemctl --user stop` → `status` rc=1.
- `.agents/tests/syn-watch-arm-silent-exit.test.sh` — **ALL PASS**, 8/8: the flood
  brake (an unchanged queue keeps the watch watching), the client's attach lines,
  a line raised with no client attached delivered to the next, the re-seat, the loud gap.
- `bash -n` clean on every edited/added script; `bin/syn-watch.sh status --detail`
  and `bin/eir-doctor.sh check` exercised live.

### Files
- `bin/syn-watch.sh`
- `bin/syn-watch-arm.sh`
- `bin/eir-doctor.sh`
- `tools/mill/systemd/ymir-syn-watch.service`
- `bin/autoboot-lib.sh`
- `bin/fleet-ensure.sh`
- `bin/ymir-autoboot.sh`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`
- `.agents/tests/syn-watch-arm-silent-exit.test.sh`
- `.agents/tests/smoke.test.sh`
- `tests/e2e/arm-service-proof.sh`
- `STRUCTURE.md`
- `README.md`
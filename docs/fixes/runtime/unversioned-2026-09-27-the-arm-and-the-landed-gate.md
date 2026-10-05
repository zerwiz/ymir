## runtime · unversioned · 2026-09-27 — the arm and the landed gate become the engine's

### Why
Plan 58 Phase 5 is one sentence: **split the gods, delete the twins, one god per
PR.** PR #224 shipped the *library* twins (classify/wake/lease/wake-grant behind
one implementation) and its own confession named what remained: the vendored
`fm-watch.sh` (1,962 lines) still carried the watcher's judgement, `fm-teardown.sh`
(2,922) still carried the landed-work gate, and the Utgard seat road still rode
`bin/agents/einherjar-spawn.sh`.

Two of those seams are this change. Both were **two copies of one behaviour**:
`bin/pi/syn-watch.sh` judged the arm's liveness and raise from bash, and
`.agents/backend/fm-watch.sh` judged the same record again; the teardown gate
decided "may this work be discarded?" in shell, with no owner in the engine that
the lifecycle verbs could call.

### What
**1 · The watcher god — Sýn's behaviour is `src/ymir_runtime/watch.py`.**

```
one_behaviour[7]{judgement,owner}
  "the lease (pid, starttime, gen, mode, session, state)","watch.read_lease / write_lease / lease_alive / next_generation"
  "the heartbeat (touch, age, staleness)","watch.heartbeat_touch / heartbeat_age"
  "the verdict: up | idle | stale | down","watch.status_state"
  "the session owner","watch.session_owner — asks bin/vault/gleipnir-lock-lib.sh, never re-derives the lock law"
  "the raise grammar: .wake-queue (content-hash flood brake), *.signal, *.check, .watcher-stop","watch.raise_line"
  "the delivery slot + the append-only journal","watch.publish"
  "the cycle and the daemon loop","watch.cycle / watch.run_daemon"
```

`bin/pi/syn-watch.sh` is now a **thin door**: help, `-v`, then
`exec "$SCRIPT_DIR/ymir-engine.sh" watch "$@"`. It defines no behaviour, so there
is nothing left to drift against a twin. The CLI, the TOON row, the stderr
remedies, and the exit codes are unchanged — the door `exec`s the interpreter, so
the pid is the same and `tools/mill/systemd/ymir-syn-watch.service`
(`ExecStart=/bin/bash <bin>/syn-watch.sh run`, `Restart=always`) is untouched.

`proc.py` gained the three primitives the arm needs and nothing else:
`pid_alive` / `proc_starttime` (the Python twin of Gleipnir's zombie- and
pid-reuse-aware liveness proof), `spawn_detached` (the `setsid … &` shape with an
opened log handle), and a `FileNotFoundError` → `rc=127` in `run()` so a missing
`gh` is a FAILED command, never a crash.

**2 · The teardown god's landed gate — `src/ymir_runtime/landed.py`.**

Reached two ways: the verb `python3 -m ymir_runtime landed <worktree>` (door:
`bin/engine/ymir-engine.sh landed`), and `stop --remove-worktree --require-landed`, which
REFUSES to remove a worktree whose work has not landed, naming the proof that said
so. The proofs are the vendored gate's own, with the vendored gate's own argv:
remote reachability · a merged PR whose head contains the local work (exact
ancestor, or every unpushed patch present by `git patch-id`) · content-in-default
via `git merge-tree --write-tree` after a fetch · the local-only `local-default`
fallback. Every uncertainty — a gh error, an unresolvable default branch, a merge
it cannot compute — is an **inconclusive refusal**, never a guess; `--force`
remains the approved-discard path.

**3 · The deletion test, applied honestly, with the outcome recorded.**

```
vendored_form[3]{file,callers,outcome}
  ".agents/backend/fm-classify-lib.sh · fm-wake-lib.sh · fm-lease-lib.sh · fm-timeout-lib.sh · fm-wake-grant.sh","the vendored island + the live route (fm-procevent via bin/agents/eindri-watch.sh)","KEPT as thin adapters (#224); the alias-table end-state stands"
  ".agents/backend/fm-watch.sh","fm-guard.sh · fm-turnend-guard.sh · fm-watch-arm.sh · fm-watch-checkpoint.sh · fm-supervise-daemon.sh · fm-claude-stop-autoarm.sh + ~10 vendored tests","KEPT — not this change's file, and DELETING it would break every one of those callers. The SEAM it duplicated (the arm's liveness, heartbeat, verdict, raise) is now the engine's, which was the point"
  ".agents/backend/fm-teardown.sh","fm-remote-secondmate-control.sh + the vendored island + its own suite","KEPT — the repoint is DECLARED, not attempted; see below"
```

**The honest refusal to repoint `fm-teardown.sh`.** Its suite
(`.agents/tests/fm-teardown.test.sh`, 87 KB, ~20 landed-work shapes) **cannot run
on this tree**: it drives `$ROOT/bin/backend/fm-teardown.sh` (`.agents/tests/lib.sh`'s
`ROOT` is `.agents/`), and `.agents/bin/` was never vendored — the island's
`bin/` does not exist here. Repointing the shell gate onto `landed.py` without that
suite is exactly the blind gamble the plan forbids ("a proof is run on a live
seat, not asserted"), so the repoint rides the next errand, after the suite is made
runnable. The new engine gate is proven by its own real-repository suite and the
door-level proof below, which is more than the shell copy has ever had here.

**Drive-by finding (named, not fixed):** `bin/README.md` is auto-generated from
script headers but its `bin[103]` count and its row set are stale — `bin/` holds
221 entries / 213 `*.sh`, and `bin/pi/syn-watch.sh` has no row at all. No guard reads
it, so it was left alone rather than half-regenerated; it belongs to the wards
errand (Phase 8).

### The proofs (run, not asserted)
- `python3 -m unittest` — **189 tests, OK** (skipped=12). `test_watch.py` (40) and
  `test_landed.py` (23) are new; the pre-existing 124 are unchanged.
- `tests/e2e/arm-service-proof.sh proof` — **PASS**, 7/7: seats with NO session
  (`session=none`, `status` rc=0), heartbeat age 1s, the client relays
  `signal: wake queue`, `kill -9` the arm → the standing client re-seats it
  (pid 2167179 → 2167965), `status` rc=1 with the arm down, Eir's `arm` row `ok`.
- `tests/e2e/arm-service-proof.sh systemd` — **PASS**, 4/4: the transient user unit
  comes active, `kill -9` the main process and `Restart=always` brings it back
  (pid 2171677 → 2171885), heartbeat fresh, `systemctl --user stop` → `status` rc=1.
- `.agents/tests/syn-watch-arm-silent-exit.test.sh` — **ALL PASS**, 8/8: the flood
  brake (an unchanged queue keeps the watch watching), the client attach, a line
  raised with no client attached delivered to the next, the re-seat, the loud gap.
- `tests/e2e/landed-gate-proof.sh proof` — **PASS**, 6/6 over real repositories
  with a real bare origin: `c-local-only-merged` → `yes|local-default`;
  `a-remote-reachable` / `d-local-only-on-remote` → `yes|remote`;
  `b-unlanded` → `no|unlanded`; `e-dirty` → `no|dirty`; `f-forced` → `yes|forced`.
- `bash -n` clean on `bin/pi/syn-watch.sh`, `tests/e2e/landed-gate-proof.sh`,
  `bin/engine/ymir-engine.sh` and every other touched script.
- `bin/pi/syn-watch.sh status --detail` against a scratch state, live:
  `arm=down mode=none unit=absent pid=none heartbeat=-1s session=none`, rc=1.

### Files
- `src/ymir_runtime/watch.py` (new), `src/ymir_runtime/landed.py` (new)
- `src/ymir_runtime/proc.py`, `__init__.py`, `__main__.py`, `stop.py`
- `src/ymir_runtime/tests/test_watch.py` (new), `tests/test_landed.py` (new)
- `bin/pi/syn-watch.sh`, `bin/engine/ymir-engine.sh`
- `tests/e2e/landed-gate-proof.sh` (new)
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md` (§5, §7.1, §7.4)
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` (the arm table)

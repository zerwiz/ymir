## runtime · unversioned · 2026-09-27 — the engine seats: plan 58 Phase 1, `src/ymir_runtime/`

### Why
The agent-execution road was the failing road: 156 `fm-*` scripts behind 22 doors,
each its own entry point, spawn/teardown/watch god scripts (3153/2922/1962 lines),
two drifted twins (`bin/*` vs `.agents/backend/fm-*`), and no seam a test could
reach without a spawn. Plan 58's first migration step is the fix: **one deep
module, four verbs** — `seat(errand) → seat_id` · `status(seat_id) → state` ·
`send(seat_id, text)` · `stop(seat_id)` — with the doors becoming thin adapters
over it. This is that step.

### What
**The engine** (`src/ymir_runtime/`, stdlib only, no build step):

```
interface[4]{verb,returns}
  "seat(errand)","seat_id — worktree + harness + backend + record + heartbeat, all hidden"
  "status(seat_id)","working | blocked | done | idle, read from the record the system already writes"
  "send(seat_id, text)","durable numbered inbox message first, pane steer second"
  "stop(seat_id)","reap the backend target, PROVE it is gone, record the terminal line"
modules[6]{file,owns}
  "worktree.py","Yggdrasil: create-or-reuse .yggdrasil/<id>, refuse a squatter, never overwrite"
  "harness.py","Hamr: harness/model/effort resolution with provenance, and the exact launch line"
  "backend.py","herdr first, tmux the verified fallback; launch · steer · liveness · kill"
  "container.py","the Utgard decision, made honestly: herdr is owned, the sandbox is REFUSED"
  "heartbeat.py","the shell condition's own judgement (silent | fresh | terminal | absent)"
  "seat · status · send · stop","the four verbs and nothing else public"
```

`seat()` records the **same meta the old door records** (same keys, same status
baseline line, same `.launch.sh`, same seat-private machine-state dir), so every
existing reader — `bin/eindri-heartbeat.sh`, Vör, Hlidskjalf's Fleet — keeps
working with no change. It also delegates rather than duplicates: the
worth-a-smith verdict is asked of `bin/herdr-run.sh`, the door that owns the
heuristic.

**The doors became thin, strangler-style and reversible:**
- `bin/ymir-engine.sh` — the door to the engine; exit **4** means "the engine will
  NOT own this errand", which is the caller's signal to keep its old road.
- `bin/ymir-engine-ensure.sh` — the engine's private venv, built at runtime when
  `src/pyproject.toml` declares a dependency. Today it declares none, so the
  honest answer is "not needed (stdlib only)"; nothing is ever committed.
- `bin/einherjar-spawn.sh` — engine-first: it hands the fully-resolved errand to
  the engine; on exit 4 it runs the road it already had, unchanged. A non-4
  failure is fatal and does NOT fall back (a half-seat is worse than none).
- `bin/eindri-start.sh` — same handoff when the caller names an errand with
  `--id`; without `--id`, or with a seat hint (`--pane/--tab/--space/--main`),
  the ordinary road runs. `YMIR_ENGINE=off` disables the handoff everywhere.

`bin/valknut-load.sh`, `.pi/**`, and the arm's `signal:/stale:/check:/heartbeat:`
grammar are **untouched**.

### The proofs (run, not asserted)
- `python3 -m unittest` — **100 tests**, unit tests beside the modules, from a bare
  command at the repo root.
- `tests/e2e/engine-proof.sh proof` — **one real errand, all four verbs, live**: a
  real pi worker in a real Yggdrasil worktree in a real tmux pane. Seat →
  `working`; the worker's own pane answered the errand; `send` filed
  `state/<id>.inbox/001.msg` and steered the pane; `stop` reaped the window and
  recorded `done: stopped … (engine stop)`. Verdict `PASS` (4 verbs).
- `tests/e2e/engine-proof.sh parity` — the old door (`YMIR_ENGINE=off
  bin/einherjar-spawn.sh`) and the engine seat the same errand: **11 recorded keys
  agree** (`kind mode yolo harness raw_launch backend isolation
  isolation_declared force locked worth_a_smith`), 8 more keys are carried by
  both records, both targets live, and **both reaps leave no orphan**.
- `bin/valknut-load.sh --status` exits 0; `git diff bin/valknut-load.sh .pi/` is empty.

### What the engine does NOT yet own (named plainly, for the next phase)
- **The Utgard sandbox is not launched.** `container.py` decides and refuses; a
  declared or forced utgard returns exit 4 and the old road keeps it until the
  sandbox module's own phase. Never a silent downgrade.
- **`--relaunch` is not owned.** An existing seat record is refused (exit 4), so
  relaunch still rides `bin/einherjar-spawn.sh`.
- **`stop()` does not delete the worktree** unless asked (`--remove-worktree`), and
  `fm-teardown`'s landed-work gates, PR lookups, and backlog transitions are NOT
  ported — reap means "the pane is gone", not "the task is closed".
- **`send()` does not read the reply.** Peek/read stays with
  `bin/eindri-control.sh`; `send` is a delivery verb, not a conversation.
- **The twins are alive.** `bin/einherjar-spawn.sh`'s own 990-line body and the
  `.agents/backend/fm-*` vendored runtime both still stand; deleting them is
  Phase 5, a later errand.
- **The model-resolver heredoc is PRESERVED, not touched (Brokk steer 001).** The
  base tree carries an indented python heredoc in `bin/einherjar-spawn.sh`'s
  `agent_yaml_local_providers` — the one that broke every dispatch until PR #215
  normalized it. This branch does **not** touch that region: `git merge-tree` of
  #215 into this branch is clean, with BOTH the column-zero heredoc and the engine
  handoff standing in the merged tree. The engine does not use the bash heredoc at
  all — `src/ymir_runtime/harness.py` resolves harness/model/effort itself — so the
  heredoc stays only for the old road until the adapter's own resolution retires.
- **Pre-existing miscount corrected:** `installation.md`'s `install[]` block
  declared 29 rows and held 30; the gate reads the declaration, so the block lied
  by one. Fixed in the same pass — a governed asset that miscounts itself is the
  class of drift plan 58 Phase 8 exists to end.

### Files
- `src/pyproject.toml` · `src/ymir_runtime/{__init__,__main__,errors,paths,proc,worktree,harness,backend,container,heartbeat,seat,status,send,stop}.py`
- `src/ymir_runtime/tests/{__init__,support,test_paths,test_worktree,test_harness,test_container,test_backend,test_heartbeat,test_seat,test_lifecycle,test_cli}.py`
- `tests/__init__.py` · `tests/test_engine.py` (the `python3 -m unittest` hinge) · `tests/e2e/engine-proof.sh`
- `bin/ymir-engine.sh` · `bin/ymir-engine-ensure.sh` (new doors)
- `bin/einherjar-spawn.sh` · `bin/eindri-start.sh` (engine-first adapters, old road intact)
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md` · `.agents/skills/galdr-ymirsystem/assets/installation.md` · `STRUCTURE.md`

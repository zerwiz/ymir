## runtime · unversioned · 2026-09-27 — the state crafts: plan 58's `src/ymir_runtime/state/`

### Why
Plan 58's language table names the state as **correctness-critical**: locks
(Gleipnir) belong in a Python module with a thin bash shim — "ONE implementation,
two readers" — because the shell owns the rules today and the harness readers
(the `.pi` / `.opencode` extensions) read the same files. The codebase survey's
top finding was the *lock-and-state resolution* card: the same question ("where
is the lock / the state?") answered in three places that once disagreed, with a
live incident behind it. Runes is the append-only chained ledger, and its
checksum format must never move. The wake queue is the durable road a finished
worker uses to reach Brokk with no arm and no session. This change moves those
crafts behind one implementation, with the shell kept as thin shims.

### What
**The state module** (`src/ymir_runtime/state/`, stdlib only):

```
state[4]{module,owns,shim}
  "lock.py","Gleipnir: state-dir · machine-state-dir · legacy-lock-path · lock-path · pointer-path · owner · pid-alive · proc-starttime · session-pid · owned · reap · acquire · release — the harness-ancestry pid and the /proc starttime that make pid reuse read as death","bin/vault/gleipnir-lock-lib.sh"
  "runes.py","the append-only chained ledger: head · escape · fold (prev + \\n + base) · flock · append · verify; never rewrites, never truncates","bin/records/runes-append.sh"
  "envelope.py","the durable wrapper state files travel in: kind · id · created · payload, encoded as key=value meta or one JSON object, written atomically (temp + os.replace)","—"
  "queue.py","the durable wake queue: the TSV <epoch>\\t<seq>\\t<kind>\\t<key>\\t<payload> line, cleaned fields, the seq file, one O_APPEND write, distinct-key reads","bin/time/brokk-wake-lib.sh (fm_wake_append · fm_wake_queued_keys_locked)"
```

**The door** is `bin/records/ymir-state.sh`: it picks the interpreter (the engine venv
when present, else system `python3`), sets `PYTHONPATH` to the tree, exports
`YMIR_ENGINE_ROOT`, and execs `python3 -m ymir_runtime.state`. Exit codes are the
module's own — **0** ran/condition true · **1** condition false or IO failed ·
**2** usage — and the shims map them onto their old shell names and
`<result-var>` conventions, so no caller changes.

**The shims keep their names, their lines, and their side effects:**
- `bin/vault/gleipnir-lock-lib.sh` defines no behaviour: every
  `gleipnir_*` function delegates, `GLEIPNIR_LOCK_ACQUIRED` is set exactly as
  before, and a door that cannot run fails **loud** (127) rather than resolving an
  empty lock.
- `bin/records/runes-append.sh` keeps `runes_append` / `runes_file_path` / `runes_lock_path`
  and `RUNES_LAST_CHECKSUM`; the CLI/library text is unchanged.
- `bin/time/brokk-wake-lib.sh`'s `fm_wake_append` keeps its validation and the recovery
  marker, holds its own queue lock, and hands the append to `queue.py`;
  `fm_wake_queued_keys_locked` reads through `queue.py`. The append is **not**
  silently dropped: a missing door returns non-zero.

`package.json` `files` gains `src/`, so a packaged install ships the door and the
module together (the engine door already required `src/` and was not shipped).

### The proofs (run, not asserted)
- `python3 -m unittest` — the full engine suite, **160 tests, 0 failures**
  (12 skips pre-existing); the state crafts add 36.
- `src/ymir_runtime/tests/test_state.py` — the **unit** proof: the state-dir
  precedence (override → Eindri-home → hoard state → home), the machine-global
  lock vs the per-home lock, pid truth (live, vanished, recycled starttime,
  nonsense), acquire/release, reap-removes-only-the-dead, the runes chain and a
  tamper that breaks it, the queue's seq bump and cleaned fields, the envelope's
  atomic meta/json round trip.
- `src/ymir_runtime/tests/test_state_parity.py` — the **parity** proof against the
  shell this replaces (kept verbatim under `tests/fixtures/state/`): a full lock
  cycle (state · lock · pointer · acquire · owner · starttime · pointer body ·
  release · reap) is **byte-identical**; a three-entry rune append, including a
  quoted/backslashed message and a multi-line one, produces a **byte-identical**
  ledger and stdout; a queue append produces a **byte-identical** line and seq
  file, and `fm_wake_queued_keys` matches the old awk. The ledger still chains
  (`runes.verify`).
- **Live parity, this seat:** the shim and the legacy library resolve the same
  state dir, lock path, pointer, machine dir, and owner on the running seat, and
  the harness pointer (`state/.lock-path`) still names the resolved lock.
- `bash -n` clean on every changed shell file.

### Not claimed / next
- The wake-queue **readers** that truncate or restore the queue
  (`saga-wake-drain.sh ack`, `fm_wake_restore_queue`, the direct appenders in
  `eindri-wake-lib.sh` / `eindri-acclaim-silent.sh` / `brokk-send.sh`) are
  unchanged: the module owns the *append* and the *distinct-key read*, which is
  where the format and the concurrency live. A later errand can route them through
  `queue.py`.
- The lock shim spawns a Python per call. It is a handful of calls per session
  start and per arm cycle, and the door is on the critical supervision path, so it
  fails loud — never silent — when the engine cannot run.
- `envelope.py` has no shell caller yet (the seat `.meta` writer lives in
  `heartbeat.py`); it is the typed shape for the next caller, unit-tested now.

### Files
- `src/ymir_runtime/state/{__init__,lock,runes,envelope,queue,__main__}.py`
- `src/ymir_runtime/tests/test_state.py` · `test_state_parity.py` ·
  `tests/fixtures/state/{gleipnir-lock-lib.legacy.sh,runes-append.legacy.sh}`
- `bin/records/ymir-state.sh` (new door) · `bin/vault/gleipnir-lock-lib.sh` ·
  `bin/records/runes-append.sh` · `bin/time/brokk-wake-lib.sh`
- `package.json` · `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`

**Correction (2026-09-27, Forseti's stack review — appended, the original stands).**
The governed asset's section headings were H2 collisions (`## 7.4` triples against
the grants' `### 7.4`), a wart the stack rebases carried. Corrected in place to
coherent H3 numbering in file order (dispatch `### 7.6` · state `### 7.7` · the
god-seams `### 7.8`), blank lines restored, nothing else changed.

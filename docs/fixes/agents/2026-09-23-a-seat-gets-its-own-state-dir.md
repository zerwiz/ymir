## agents · unversioned · 2026-09-23 — a seat gets its own state dir, not just its own lock

### Why
- **A worker seat clobbered the primary's lock POINTER, and supervision died.**
  The per-seat helm fix (#124) set `BROKK_MACHINE_STATE_DIR` for a seat, so its
  **lock** resolved to its own path
  (`bin/gleipnir-lock-lib.sh` → `gleipnir_lock_path`). But the **pointer** file
  (`.lock-path`, the record the pi extension reads) resolves through
  `gleipnir_state_dir`, which is keyed off `BROKK_STATE_OVERRIDE`/`BROKK_HOME` —
  and a seat shares `BROKK_HOME` with the primary. So the seat wrote its own
  pointer over the primary's.
- **Proven live (2026-09-23).** The `snotra` seat started, and the shared
  pointer became:

  ```
  state/.lock-path  →  /home/heimdall/.local/state/ymir/seats/snotra-q/brokk.lock
  ```

  The primary's extension read that pointer, found the seat's lock pid
  (`3639778`) outside its own ancestry, classified ownership as `other`, and
  refused to arm:

  > `watcher: read-only - session lock is held by another brokk session`

  The primary (`2796305`) *did* hold its own lock the whole time. The lock was
  never contended — only the pointer was, and the pointer was the whole failure.

### Fix
- **`bin/herdr-run.sh`** — a seat now gets **both** variables, pointing at one
  private state dir:
  - `BROKK_MACHINE_STATE_DIR=<seat dir>` — the lock.
  - `BROKK_STATE_OVERRIDE=<seat dir>` — the state the pi extension reads the
    pointer from.

  With both set, `gleipnir_lock_path` and `gleipnir_lock_pointer_path` resolve
  into the *same* directory, so a seat's pointer and lock agree and neither
  touches the primary's. `seat_state_dir()` replaces `seat_state_env()` and the
  three seat roads (`seat_tab`, `seat_space`, `seat_pane`) pass both `--env`
  flags.
- **`bin/pi-seat.sh`** — the same two variables on its tab/pane creation.

### What was deliberately NOT changed
The pointer could instead have been moved into the machine state dir (beside the
lock) — the tidier invariant. It was rejected because three bash readers consult
the pointer at the **home** state path and would have silently fallen back to the
legacy `.lock`:

- `bin/brokk:34`
- `bin/brokk-lease-lib.sh:151`
- `bin/brokk-lease.sh:130`

Giving the seat its own state dir achieves the same invariant (pointer and lock
in one directory) without touching the primary's contract.

### Verification
- `bash -n` clean on both files.
- `seat_guard` still passes: the seat dir is distinct from the primary's.
- Both scripts now set `BROKK_STATE_OVERRIDE` (6 references in `herdr-run.sh`,
  2 in `pi-seat.sh`).
- The live session was repaired by restoring the pointer
  (`~/.local/state/ymir/brokk.lock`) and the watcher re-armed cleanly.

### Files
- `bin/herdr-run.sh`
- `bin/pi-seat.sh`

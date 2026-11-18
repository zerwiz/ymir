## snotra · 2026-11-18 — the resolver moved, and an empty window is a skip, not a failure

### Files
- `systems/snotra/services/cron/snotra-pipeline.sh` (the door now reads the resolver where it lives, and an
  empty `--recent` window exits 0)

### What was wrong
- The pipeline's `--recent` branch called `python3 "$S/snotra_paths.py"`, where `S` is `systems/snotra/`.
  **The resolver moved to `systems/snotra/services/record/snotra_paths.py`** (plan 129, the retirement shim
  at `bin/time/snotra/snotra_paths.py`), so that call died with
  `can't open file '…/systems/snotra/snotra_paths.py': [Errno 2] No such file or directory`.
- The call's stderr went to `/dev/null`, so the door saw an empty list and reported
  `snotra-pipeline: no meeting folder given` with **exit 2**. The cron row
  (`run --recent 1 --draft`) therefore failed on **every** run — a HIGH wake with no actionable output, which
  is exactly what the 2026-11-18 04:10 wake said.
- Nothing was ever transcribed through this row: the failure was not intermittent, it was structural.

### What now stands
- `RESOLVER="$S/services/record/snotra_paths.py"`, the same file `bin/time/nornir-job-snotra-mail.sh` already
  reads, so the two doors cannot disagree again.
- **A missing resolver is a failure** (`exit 1`, naming the path) and **a resolver that errors is a failure**
  (`exit 1`, carrying its last line) — a broken shelf list can no longer masquerade as "no meetings".
- **An empty window is a clean skip**: `SKIP — no meeting folder touched in the last N day(s)`, `exit 0`.
  A quiet day is not a failed job (Rule 25: a clean skip is a pass).

### Verified
- `bash -n` clean.
- `snotra-pipeline.sh run --recent 1 --draft` before: `no meeting folder given`, rc 2.
- Same command after: `snotra-pipeline: SKIP — no meeting folder touched in the last 1 day(s)`, **rc 0**.
- The resolver itself answers at its new home: `python3 systems/snotra/services/record/snotra_paths.py --recent 5`
  lists the shelves it can see, and the pipeline parses that list unchanged.

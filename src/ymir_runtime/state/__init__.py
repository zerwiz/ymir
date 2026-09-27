"""state — the correctness-critical state, in Python, with thin bash shims.

Plan 58's folder shape: `src/ymir_runtime/state/` holds the four state crafts as
deep modules —

  lock      (Gleipnir)  the session lock: acquire · release · owner · pid-alive
  runes                 the append-only chained audit ledger
  envelope              the durable, typed wrappers state files travel in
  queue                 the durable wake queue, appended atomically

`bin/gleipnir-lock-lib.sh`, `bin/runes-append.sh`, and the wake-queue
primitives in `bin/brokk-wake-lib.sh` are THIN SHIMS over these modules: the
shell keeps its names and its lines, the correctness lives here once. Every shim
is proven by parity — the same lock cycle, the same rune line, the same queue
record — never by assertion.
"""

from __future__ import annotations

from .envelope import Envelope
from .lock import (
    LockState,
    acquire,
    inspect,
    is_eindri_home,
    legacy_lock_path,
    lock_owned,
    lock_owner,
    lock_path,
    machine_state_dir,
    pid_alive,
    pointer_path,
    proc_starttime,
    reap,
    release,
    session_pid,
    state_dir,
)
from .queue import Wake, WakeQueue, clean_field, dedupe, parse_all
from .runes import Rune, append as append_rune, ensure_head, file_path, last_checksum, verify

__all__ = [
    "Envelope",
    "LockState",
    "Rune",
    "Wake",
    "WakeQueue",
    "acquire",
    "append_rune",
    "clean_field",
    "dedupe",
    "ensure_head",
    "file_path",
    "inspect",
    "is_eindri_home",
    "last_checksum",
    "legacy_lock_path",
    "lock_owned",
    "lock_owner",
    "lock_path",
    "machine_state_dir",
    "parse_all",
    "pid_alive",
    "pointer_path",
    "proc_starttime",
    "reap",
    "release",
    "session_pid",
    "state_dir",
    "verify",
]

## runtime · unversioned · 2026-10-20 — the arm was blind to its own session

### What

`bin/pi/syn-watch.sh status` reported `idle` with `session=none` while the watcher was
alive (pid, heartbeat, armed marker). The cause was a path: `session_owner()` in
`src/ymir_runtime/watch.py` looked for the lock library at `<root>/bin/gleipnir-lock-lib.sh`;
it lives at `<root>/bin/vault/gleipnir-lock-lib.sh`. The function returned `"none"`
without ever querying the lock, so every lease was written `session=none`.

Also found: the engine venv was an editable install pointing at a stale worktree
(`.yggdrasil/schema-the-config/src`), so a main-tree fix would not reach the daemon.

### Fix

- Correct the library path, and add a fallback that reads the lock file directly when
  the owner reader is empty (liveness is still checked).
- Repoint the venv editable install to `/home/heimdall/ymir/src`.
- Re-arm once, restart the unit.

### Verified

- Before: `"idle", … "session","none"`.
- After: `"up","systemd","active","189896","1","60","1722138","yes"` and the lease
  carries `session=1722138` — the live Pi pid.
- `python -c` with the venv now imports `ymir_runtime` from `/home/heimdall/ymir/src`.

### Not verified

- No regression test yet for `session_owner` (plan 91 §6).
- No guard yet against an editable install pointing at a worktree.

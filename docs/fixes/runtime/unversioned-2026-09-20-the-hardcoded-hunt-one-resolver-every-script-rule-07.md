## runtime · unversioned · 2026-09-20 — the hardcoded hunt: one resolver, every script (Rule 07)

### Why
The Allfather's question — *look for more hardcoded* — found a whole class, and one
of them silently won over its own fix.

- **Nine scripts carried their own home default**, and some still named the
  **dead** `$HOME/Documents/Ymir` (the home moved to `Documents/ymirhome`): the
  ledger (`bin/runes-append.sh`), `bin/ymir-validate.sh`, `bin/smidja-bootstrap.sh`,
  `bin/ymir-style.sh`, `bin/saga-session-start.sh`, `bin/mimir-bridge.py`,
  `bin/bootstrap-macos.sh` (a `/home/${VM_USER}` literal), and
  `.agents/skills/lifecycle/smoke_test.sh`. All now resolve through
  `ymir_home_root` (env → the recorded choice → the ONE default in
  `bin/hoard-lib.sh`).
- **The subtle one:** `bin/smidja-board.sh` *did* call the resolver — but set
  `YMIR_HOME` from a literal first, so the resolver saw a non-empty value and kept
  the **dead** path. A literal before the call is not a default; it is an override.
  The literal is gone.
- **Tunnel names are the operator's** (`bin/gjallarhorn-expose.sh`): the domain and
  suffix no longer default to one operator's (`zerwiz.org` / `dell`) — they read
  `$YMIR_HOME/config/tunnel.env`, env first, and skip honestly when unset.
- **Two assets carried a domain that does not exist** — `hall.ymir.zerw.org`
  (missing the `z`) — now `hall.ymir.zerwiz.org`.
- **The record is written:** `~/.config/ymir/home` → `~/Documents/ymirhome`, so the
  machine's choice is explicit rather than resting on a default.
- `apps/hlidskjalf/server/index.ts` reads the recorded home before its default.

Not leaks, and left alone: the public owner identity (`zerwiz`, `zerwiz.org`) is
deliberately allowed by `bin/public-guard.sh`; the guard is silent on the tree.

galdr-reread: `brokk-distro-runtime.md` (one resolver, every script).

### Files
- `.agents/skills/lifecycle/smoke_test.sh`
- `apps/hlidskjalf/server/index.ts`
- `bin/bootstrap-macos.sh`
- `bin/gjallarhorn-expose.sh`
- `bin/hoard-lib.sh`
- `bin/mimir-bridge.py`
- `bin/public-guard.sh`
- `bin/runes-append.sh`
- `bin/saga-session-start.sh`
- `bin/smidja-board.sh`
- `bin/smidja-bootstrap.sh`
- `bin/ymir-style.sh`

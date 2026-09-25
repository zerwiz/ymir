## hoard · unversioned · 2026-09-25 — a decoy lock must never land in the hoard

### Why
Migration `0007-one-state-dir` moved the tree's `state/.lock` and
`.lock.starttime` into the **hoard root** — because the home had no such names.
That left a **dead pid** (`2119780`) sitting at `$YMIR_HOME/state/.lock`, where it
can masquerade as a per-home session lock, and it surfaced immediately as Eir's
`lock` detail. The decoy's lock files are never truth: the primary's lock lives
machine-global (`${XDG_STATE_HOME:-$HOME/.local/state}/ymir/brokk.lock`) and is
named by `state/.lock-path`.

- **The migration now recovers those two names unconditionally** —
  `.lock` · `.lock.starttime` always go to `.recovered-tree-state/`, never to the
  home root, whatever the home already holds. Idempotent like the rest.
- **Proved live:** the stale `$YMIR_HOME/state/.lock` and `.lock.starttime` were
  moved into `.recovered-tree-state/`; the live pointer
  (`state/.lock-path` → `…/ymir/brokk.lock`, owner `315702`) was not touched.

galdr-reread: `brokk-distro-runtime.md` §4 already names the machine-global lock
and the pointer; no further asset change.

### Files
- `.agents/migrations/0007-one-state-dir.sh`

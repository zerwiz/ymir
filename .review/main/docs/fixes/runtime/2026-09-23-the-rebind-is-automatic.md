## runtime · unversioned · 2026-09-23 — the rebind is automatic: install, update and merge all bind the harnesses

### Why
**No install or update should leave the harness surfaces stale** — and none of
them bound the surfaces automatically.

Pi loads its extensions from `${HOME}/.pi/agent/extensions/`, deployed from the
repo's `.pi/shared/extensions/` by `bin/valknut-load.sh`. So when the supervision
extension was fixed in the repo, **pi kept running the old code**, and a hand-copy
into the global home became the only way to make the fix real. That is the wrong
shape: a merged fix must reach the harness by the ordinary path.

Three gaps:
1. `bin/ymir-install.sh` ran `valknut-load.sh` but never seated a hook, so a
   *merge* did not rebind.
2. `bin/groa-update.sh` (Gróa, the updater) ran migrations after a pull but
   **never rebound the surfaces**.
3. Nothing asked git where the hooks live — in a worktree `.git` is a *file*, so a
   naive `$ROOT/.git/hooks` check reported "not a git checkout" and skipped.

### Fix
- **`bin/valknut-load.sh --install`** — seats a **post-merge** hook (idempotent),
  found via `git rev-parse --git-path hooks` and pointing at the MAIN tree, so a
  merge rebinds the surfaces.
- **`bin/ymir-install.sh`** — the `loaders` step now also runs
  `valknut-load.sh --install` and reports `post-merge rebind hook seated`.
- **`bin/groa-update.sh`** — after `ymir-migrate.sh`, runs
  `valknut-load.sh --all --global` and reports `rebound (agents · skills · pi
  extensions)`; a failure WARNs with the `--status` hint rather than passing
  silently.
- **Assets updated in the same change:** `installation.md` (the `loaders` row),
  `harness-integration/README.md` (the rebind law, the running-session truth, and
  the git-asked hooks path).

### The truth this records
A running session **keeps the code it loaded**. A fixed extension is live from
the **next** pi session, never the current one — which is why repairing the
extension and repairing the session are two different acts.

### Verification
- `bash -n` clean on all three scripts.
- `valknut-load.sh --install` seats the hook at the path git reports:
  `/home/heimdall/ymir/.git/hooks/post-merge`, pointing at
  `/home/heimdall/ymir/bin/valknut-load.sh --all --global`.
- Compliance gate: **15/15 PASS**.

### Files
- `bin/valknut-load.sh`
- `bin/ymir-install.sh`
- `bin/groa-update.sh`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`

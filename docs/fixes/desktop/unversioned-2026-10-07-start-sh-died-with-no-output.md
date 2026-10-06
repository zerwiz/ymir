## desktop · unversioned · 2026-10-07 — `scripts/start.sh` died with no output because two resolvers looked in `bin/`

### Why

The Allfather said *"start Runes, the seer's doors, and Hlidskjalf."* `scripts/start.sh` —
the documented way to raise the whole hall — exited **1 with zero bytes of output**. Not a
warning, not a failed service: nothing at all. A start script that dies silently cannot be
debugged from its own report, so the trace had to come from `bash -x`, and it ended here:

```
+ smidja_visualizer_dir SMIDJA_VIZ
+ smidja_factory_dir factory
+ app_dir smidja _smd_c
+ _smd_c=/home/heimdall/ymir/bin/.agents/skills/smidja-factory
+ '[' -d /home/heimdall/ymir/bin/.agents/skills/smidja-factory/apps/visualizer ']'
+ printf -v factory %s ''
+ return 1
```

**`<repo>/bin/.agents/` has never existed.** The skill shelf is at `<repo>/.agents/`. Both
resolvers walked up **one level too few**:

- `bin/desktop/smidja-lib.sh` — `$(dirname "${BASH_SOURCE[0]}")/..` from `bin/desktop/` is
  `<repo>/bin`, so it looked for `<repo>/bin/.agents/skills/smidja-factory`.
- `bin/seat/sessrumnir/app-lib.sh` — the same shape from `bin/seat/sessrumnir/` is
  `<repo>/bin/seat`, where no `apps/` and no `.agents/` has ever lived, so **every** app
  surface resolved to empty.

Under `set -e` a resolver returning 1 took the whole hall down with it. And because both were
called inside `smidja_visualizer_dir`/`app_dir` rather than checked, the failure surfaced as
an absence rather than an error.

**Why one level too few is such a reliable trap here:** most of `bin/` sits two levels down, so
`../..` is the checkout and `..` is `bin/`. A resolver written for the wrong depth looks
perfectly reasonable and resolves to a directory that *exists* — which is why it fails by
returning nothing instead of by looking obviously wrong.

### Fix

Both resolvers now ask git before guessing, and try both depths — the shape
`bin/bridge/bifrost-bridge.sh` and `bin/bridge/mimir-bridge.sh` already used for
`ymir-platform.sh`:

- `smidja_factory_dir` — `git -C <script dir> rev-parse --show-toplevel` first (accepted only
  when it actually holds `.agents/`), then `<script dir>/../..` then `/..`, choosing the first
  that holds `.agents/`.
- `app_dir` — same shape, accepting a candidate only when it holds `apps/`.

An explicit `YMIR_ROOT_DIR` still wins outright, so nothing that sets it changes.

### Verified

- `smidja_visualizer_dir` → `/home/heimdall/ymir/.agents/skills/smidja-factory/apps/visualizer`
  (was empty).
- `app_dir hlidskjalf` → `/home/heimdall/ymir/apps/hlidskjalf` (was empty).
- Both resolve correctly **inside a worktree** as well, because the git answer follows the
  worktree — verified in `.yggdrasil/fix-dispatch-silent`.
- `bash -n` on both. `scripts/start.sh` now exits **0** and raises the hall.

### Not fixed, and named

- **Sessrúmnir, the seat-hall, still does not rise** (`bin/desktop/sessrumnir.sh start`). It is
  reported plainly rather than swallowed, which is the correct behaviour and is why it was
  visible at all. Undiagnosed; not this fix's business.
- **Bifrost (`:4603`) still refuses to start**, and correctly: it needs `OPENCODE_GO_API_KEY`,
  which is a credential and therefore not something a start script may conjure. A door that
  will not open without a key is a door that is correctly shut.
- This is the **second** family of one-level-too-few resolvers found in two days (see
  `docs/fixes/agents/unversioned-2026-10-06-the-errand-door-reported-every-verdict-wrong.md`,
  where `local-model-lock.sh` missed `bin/vault/hoard-lib.sh` the same way). A house-wide audit
  of every `dirname "${BASH_SOURCE[0]}")/..` root is **owed** and is not done here.

### The law this earns

> **A resolver that resolves to nothing must fail where it resolves, not three calls later.**
> `scripts/start.sh` reported nothing at all because a library's empty return was treated as a
> fact rather than a fault. Silence shaped like success, again — the third time in forty-eight
> hours, and the third time found only by running the thing rather than reading about it.
# The bin move counted its roots one level short — 122 doors resolved the repo as `bin/`

**Dated:** 2026-10-07 · **Component:** runtime · **Branch:** `fix/bin-move-missed-callers`

## The symptom

The 250-door restructure moved scripts from `bin/` to `bin/<sub>/`. A door that
defined its repo ROOT as one level up

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # <repo>/bin/agents
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"  # -> <repo>/bin  (wrong)
```

now landed on `bin/`, which owns no `.agents/`, `state/`, `tools/` or `apps/`. The
failure was silent by shape: `$ROOT/.agents/backend/…` resolved to
`<repo>/bin/.agents/backend/…`, a path that never existed, so live doors read empty.

Measured in the live tree — `ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"`
was the top of 122 scripts, including `bin/agents/eindri-watch.sh` (its
`$ROOT/.agents/backend/fm-procevent-when.sh`), `bin/agents/research-round.sh`
(`$ROOT/.agents/agents/<figure>.md`), `bin/agents/eindri-review-spawn.sh`
(`$ROOT/.agents/assets/templates/…`, `$ROOT/state`), `bin/engine/autoboot-lib.sh`,
`bin/fleet/fleet-ensure.sh`, `bin/bridge/mcp-gateway.sh`, and all of `bin/backend/`.

Depth is not uniform — 106 of the doors sit at `bin/<sub>/`, 7 at
`bin/<sub>/<subsub>/` — so counting `..` a fixed number of times cannot be right
for all of them. That is Rule 12: **a door may never resolve the repo by counting
`..`**.

## The mend

Every ROOT/HOME definition now walks up to the tree that owns `.pi/` and `RULES/`,
the same idiom `bin/seat/valknut-load.sh` and `bin/gates/guards/secret-guard.sh`
already use:

```bash
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && \
  while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
```

Sibling references (`$SCRIPT_DIR/../fleet/agents-config.sh`) are untouched — they
resolve within `bin/` and were always correct. An explicit `BROKK_ROOT_OVERRIDE` /
`FM_ROOT_OVERRIDE` still wins.

## Two more families the same move left behind

**The `hoard-lib` loaders (78 sites).** A door at `bin/<sub>/` looked for the vault
library at `$(dirname "$X")/bin/vault/hoard-lib.sh` → `bin/bin/vault/…`, so
`hoard_state_dir` never ran. `bifrost-bridge.sh` died on the unbound `YMIR_STATE_DIR`
this leaves behind — 520 restarts, `set -u` naming the wrong fault. Each candidate
now tries the two real depths (`$X/../vault/…` and `$X/../../vault/…`).

**The sibling-lib loaders (20 sites).** `app-lib`, `smidja-lib`, `electron-lib`,
`ymir-platform` were loaded the same off-by-depth way. They now load through the
walked repo root, so the same line is right from `scripts/`, `bin/<sub>/` and
`bin/<sub>/<subsub>/`.

Also mended: `autoboot-lib.sh`'s machine-lock probe read a lock that need not exist
(`~/.local/state/ymir/brokk.lock`) without a `-r` guard, printing a spurious
`No such file or directory` on every verify.

Also repointed here: `package.json`'s `bin.ymir` → `bin/engine/ymir.js` (the CLI
moved), with the three callers that named the old `bin/ymir.js`
(`scripts/start.sh`, `bin/forge/npm/npm-pretest.sh`, and the `ymir-update-check.sh`
comment). `npm-pretest` also stops counting `bin/`'s top-level entries (now
directories) and counts the door files it meant to count.

## Proof

```bash
# from bin/agents and from bin/gates/guards — both walk to the checkout
bash -c 'SCRIPT_DIR=<repo>/bin/agents; …; echo "$ROOT"'   # -> <repo>
bash -n <every changed script>                            # all syntax OK
bin/fleet/fleet-ensure.sh verify                          # verdict: ok (10/10 active)
```

## Not this note's business

The Pi extension **doctrine** — `RULES/13-pi-extensions.md`,
`.pi/extensions/README.md`, the `PI_EXT_SRC` half of `bin/seat/valknut-load.sh`,
`.agents/tests/pi-extensions.test.sh` and the `harness-integration` table — still
describes the retired two-home extension design that commit `ac5fd8ad` (2026-10-04)
replaced with one tree at `.pi/extensions/`. That reconciliation is its own PR.

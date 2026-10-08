# The bin move left its callers on the old flat doors — and a door that lives two levels down

**Dated:** 2026-10-07 · **Component:** runtime · **Branch:** `fix/bin-move-missed-callers`
**Found on:** omarchy (Pi 0.99.2)

## The symptom

Pi would not seat. At startup it printed, and then refused a session:

```
Error: Failed to load extension "<repo>/.pi/extensions/elder.ts":
  Failed to load extension: Command failed: bash <repo>/bin/hodd.sh path
Error: Failed to load extension "<home>/.pi/agent/extensions/gna-pi-watch.ts":
  Tool "gna_watch_arm" conflicts with <repo>/.pi/extensions/gna-pi-watch.ts
Error: Failed to load extension "<home>/.pi/agent/extensions/ymir-well.ts":
  Tool "well_recall" conflicts with <repo>/.pi/extensions/ymir-well.ts
```

and supervision was off, so the turn-end guard fired:

```
RODD_OP: v1 turn-end-guard: TURN WOULD END BLIND - supervision is off.
```

## Two faults, one move

The 250-door restructure moved the doors into `bin/<sub>/` (`bin/pi/`,
`bin/vault/`, `bin/gates/`, …). Two classes of caller were left behind.

**1. Flat paths that moved.** The systemd unit templates, the Pi extension
`execFileSync` doors, and the MCP gateway's engine lookup still named the old flat
door:

```
tools/mill/systemd/ymir-syn-watch.service   ExecStart=…/bin/syn-watch.sh   → bin/pi/syn-watch.sh
tools/mill/systemd/mcp-gateway.service      …/bin/mcp-gateway.sh           → bin/bridge/mcp-gateway.sh
tools/web/systemd/{bifrost,mimir}.service   …/bin/{bifrost,mimir}-bridge.sh → bin/bridge/
tools/web/systemd/nornir.service            …/bin/nornir-cron-start.sh     → bin/time/
.pi/extensions/*.ts                         bin/hodd.sh                    → bin/vault/hodd.sh
                                            bin/queue.sh                   → bin/gates/queue.sh
                                            bin/ci-verify.sh               → bin/gates/
                                            bin/calendar-ask.sh            → bin/time/snotra/
                                            bin/saga-session-start.sh      → bin/time/
                                            bin/{skuld-branch-*,brokk-*}   → bin/skuld/ · bin/agents/ · bin/time/
                                            bin/{eir-doctor,groa-update}   → bin/agents/
```

The systemd templates are the silent ones: the unit's **comment** had already been
repointed to `bin/pi/syn-watch.sh status`, so every listing looked right while
`ExecStart` still ran the dead door. `ymir-syn-watch.service` exited 127 in an
8-restart loop and the watch was down the whole time.

**2. Roots resolved by counting `..` (Rule 12).** A door that lives two levels
down resolved the repo as `$SCRIPT_DIR/..` — one level short — landing on `bin/`,
which owns no `tools/` and no `apps/`:

```
bin/fleet/fleet-ensure.sh   ROOT=$SCRIPT_DIR/..        → bin/   (templates not found)
bin/bridge/mcp-gateway.sh   ROOT=$SCRIPT_DIR/..        → bin/   (engine not found)
```

`fleet-ensure` under that wrong root **retired** the live listeners on `:3888`,
`:3889` and `:8437` and then could not re-raise them — the hall went dark. It also
truncated seven unit files (`sed` against a missing template produced empty files).

## The mend

- Every systemd template names its real `bin/<sub>/` door.
- Every Pi extension door names its real `bin/<sub>/` door; the two imports the
  one-tree rewrite dropped (`execFileSync`, `homedir`) are restored in
  `gna-pi-watch.ts`.
- `bin/fleet/fleet-ensure.sh` and `bin/bridge/mcp-gateway.sh` resolve ROOT by
  **walking up to the tree that owns `.pi/` and `RULES/`** — never by counting
  `..` (Rule 12). `fleet-ensure` also exports `YMIR_ROOT_DIR` so `app-lib`'s
  `app_dir` finds `apps/` without a caller-supplied override.
- `constellation/registry.ts`'s root marker tests for the `bin/` **directory**,
  not the moved `bin/hoard-lib.sh` door.

## Proof

```
$ bin/pi/syn-watch.sh status
  "idle","systemd","active",…,heartbeat_age <60,armed,…
$ echo '{"stop_hook_active":false}' | bin/gates/guards/syn-turnend-guard.sh ; echo $?
  0
$ pi -p --no-session --offline "reply ok"
  ok
$ bin/fleet/fleet-ensure.sh ensure
  hlidskjalf-spa active · hlidskjalf-gate active · smidja active · mimir active · syn-watch active
```

## Not fixed here — recorded, not guessed

- `bin/engine/autoboot-lib.sh` resolves `AUTOBOOT_ROOT` as `$SCRIPT_DIR/..` (now
  `bin/`) — the same Rule 12 fault, unscanned for its callers.
- The `bin/` tree still holds other `$SCRIPT_DIR/..` roots and flat `bin/X.sh`
  references (skill assets, docs, tests, `package.json`'s `bin.ymir` →
  `bin/ymir.js`, which now lives at `bin/engine/ymir.js`).
- **Doctrine drift.** `RULES/13-pi-extensions.md`, `.pi/extensions/README.md`,
  `bin/seat/valknut-load.sh` (`PI_EXT_SRC`) and `.agents/tests/pi-extensions.test.sh`
  still describe the retired **two-home** design (source `.pi/shared/extensions/`,
  deploy to `~/.pi/agent/extensions/`, project tree as no-op stubs). Commit
  `ac5fd8ad` (2026-10-04) deleted `.pi/shared/extensions/` and made
  `.pi/extensions/` the one home; the docs and the loader were never reconciled.
  This fix makes the **code** true to that decision; the doctrine still needs its
  own pass.

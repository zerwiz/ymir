# runtime · 2026-11-14 — a release flip restarts the services that run from a release

**Component:** runtime · **Branch:** `eindri/hall-follow` (plan 275, item 27)
**Files:** `bin/engine/release.sh`, `bin/engine/release-services.sh` (new)

## Why

Measured in plan 275 §2026-11-14 03:55: the SPA (`:3888`, pid 2683) and the gate (`:3889`,
pid 1408) had been raised at boot from `releases/e713188ca4e2` **eight hours after** the pin
moved to `babae37aa7b8`. A release flip moves one link (`releases/current`) and nothing else,
so every service started before the flip keeps answering from the release it started in — and
every fix since `e713188c` was invisible in Hlidskjalf until a reboot.

## What changed

**One door names the services.** `bin/engine/release-services.sh`:

```
release-services.sh list                     # the long-running services that run from a release
release-services.sh status [--toon|--json]   # unit · state · pid · release · on_pin · started · why
release-services.sh restart [--only-stale] [--dry-run]
```

It does **not** keep a second list of services: it reads the one register,
`.agents/config/units.yaml`, through `bin/engine/units.sh list --restart` — so a service joins
this door by being registered, and a unit marked `restart: false` (snotra-ear, snotra-detect,
groa-agent, gimli-project, stt-shim, rodd-client) is deliberately not restarted by a flip.

**"Which release" is measured, never guessed.** A process's cwd is a *resolved* path: a service
raised through the pin while the link pointed at `releases/<sha>` stores `<sha>`, so
`/proc/<pid>/cwd` (and then the command line) is asked first. A service with no path into the
release (Bifrost has no `WorkingDirectory`) is judged by **when it started** against the
release's own build stamp (`.release-proved`): started before the release existed means it is
running older code, and the row says so in words — `started before 7ae529759d0b was built`.

**`flip` finishes the job.** After the link moves, `release.sh flip` restarts the active
services (reporting each: `restarted` / `current` / `skipped` / `FAIL`), then prunes — the
pruner now runs *after* the restart, so a release still held by a desktop window is kept and one
held only by a service that has just been restarted is free to go. `--no-restart` and
`YMIR_RELEASE_RESTART=off` hold the restart and **say** that they did, and `release.sh restart`
runs the restart alone (for a hand that flipped with it held).

Desktop windows are never restarted: an open window keeps the release it started from, which is
the design, and closing a window the operator is using is not this door's work.

## How it was proved

```
bash bin/engine/release-services.sh status        (14 rows)
  "hlidskjalf-gate.service","active","1408","e713188ca4e2","0",…,"started from e713188ca4e2"
  "hlidskjalf-spa.service", "active","1409","e713188ca4e2","0",…,"started from e713188ca4e2"
  "smidja.service",          "active","1425","e713188ca4e2","0",…,"started from e713188ca4e2"
  "bifrost.service",         "active","1399","pin","0",…,"started before 7ae529759d0b was built"
release-services.sh status --json                 → valid JSON, pin 7ae529759d0b
release-services.sh restart --dry-run             → names the 9 it would restart, the 5 stopped it skips
bash -n bin/engine/release.sh bin/engine/release-services.sh → exit 0
release.sh restart                                → "skipped — no bin/engine/release-services.sh in <release>"
                                                     (correct: the running release predates this change)
```

The Runtime page reads the same door (`/api/runtime.services`) and shows each service's release,
warning in `--ymir-warn` when `onPin` is false — so the next stale service is visible without a
shell.

## Not done, named

- **Bifrost's release cannot be named from a path** (the unit has no `WorkingDirectory`), so its
  row says `pin` plus the start-time judgement rather than a sha. That is the honest answer, and
  it is enough to say "this one is stale".
- **A flip cannot restart the app that is running the flip** (the gate serving the page). It is
  restarted like any other service and the page reloads; the SPA is a separate service and is
  unaffected.

## CHANGE LOG

- 2026-11-14 — `release.sh flip` restarts the release services and prunes afterwards;
  `bin/engine/release-services.sh` is the one door that says which release each one runs.

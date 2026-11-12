# No helm, no errand — and the helm runs the pin

## What it is

An errand (an Eindri worker) reports to the arm, the helm that watches the house. Before
this change a worker could be sent out with no arm running, and its report landed where
nobody read it. Now the seat door refuses to send a worker when no helm is held.

The second half: the arm and Rödd run the **pinned runtime**, the checkout named in
`<home>/config/runtime.env`. They no longer run whatever branch the working tree stands on.

## What you need

- A running arm: `bin/pi/syn-watch.sh status` says `up` or `idle`.
- A pinned runtime: `YMIR_RUNTIME_DIR` in `<home>/config/runtime.env`. The install sets it;
  `bin/engine/runtime-deploy.sh` moves it and restarts its units.

## The commands

| Command | What it answers |
|---|---|
| `bin/pi/arm-pin.sh status` | One line: `pin <sha> · <n> behind` |
| `bin/pi/arm-pin.sh check` | Fetches, then names every finding: behind, dirty, off its branch, or a surface running outside the pin |
| `bin/agents/eir-doctor.sh check` | The `armpin` row reads the same door |
| `bin/agents/groa-update.sh` | Fast-forwards the pin with the homes and re-proves its units |
| `apps/rodd/start.sh --install-unit` | Renders `ymir-rodd.service`, whose ExecStart names the pin |

## How a refusal reads

```
refused: no helm, no errand — no arm lease at <home>/state/.arm.lease
help: seat a helm first (bin/pi/syn-watch-arm.sh --restart from a session, or bin/pi/syn-watch.sh start), or set YMIR_DISPATCH_NO_HELM=1 to dispatch without one (it is recorded in the meta)
```

The door also refuses a dead helm pid, a reused pid (its start time no longer matches), a
heartbeat older than `BROKK_WATCH_HEARTBEAT_STALE_SECONDS` (60 by default), a lease for
another house, and an arm shelf that cannot be written.

## Limits

- `YMIR_DISPATCH_NO_HELM=1` sends a worker with no helm. The meta records
  `helm_bypass=YMIR_DISPATCH_NO_HELM=1`, so the orphan can be found later.
- `YMIR_ARM_TREE=1` and `YMIR_RODD_TREE=1` let a developer run this checkout's arm client
  or face. They say so on every run.
- `YMIR_ENGINE=off` on the spawn script skips the engine, and so skips the gate. It is
  the existing loud override.

## If it does not work

- **Every spawn is refused:** run `bin/pi/syn-watch.sh status`. If the arm is down, start it.
- **The arm client prints `read-only - helm: refused — no pinned runtime`:** set
  `YMIR_RUNTIME_DIR` in `runtime.env`, or run `bin/engine/runtime-deploy.sh`.
- **`armpin` is broken:** read `bin/pi/arm-pin.sh check`. A dirty pin is never moved by an
  update; look at its uncommitted files first.

## CHANGE LOG

- **2026-11-12** — Written, and carried into main by the gathered batch; from here appended, never rewritten.

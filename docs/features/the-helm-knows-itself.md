# The helm knows itself

## What it is

The session that holds the helm writes who it is into the arm lease: its name, what it is for, which machine
and fleet role it stands on, and which pinned code it runs and how far behind that is. One command reads it
back as one row.

Rödd, the voice, now runs the pinned runtime too, and her refusals are keyed so the same one never toasts twice.

## What you need

- A seat record (`~/.pi/agent/extensions/.ymir-seat`) or a hostname, and a fleet registry that names your role.
- A pinned runtime: `YMIR_RUNTIME_DIR` in `$YMIR_HOME/config/runtime.env` (the default is `~/ymir-runtime`).

## Do it

```bash
bash bin/voice/rodd-arm.sh who               # the one row: seat · role · charter · host · fleetrole · pin · behind · gen · pid · heartbeat
bash bin/seat/helm-identity.sh --line        # the same answer as one sentence (the session digest prints it)
bash bin/engine/ymir-engine.sh identity --check   # can THIS machine hold the helm?
bash bin/seat/armpin.sh                      # is the pin current, and does every supervisor run it?
```

## Notes & limits

- A seat with no sealed name shows `unnamed`. It still holds the helm.
- A machine that cannot name its host or fleet role is refused the helm, and the refusal names the field.
- Rödd started from any tree hands over to the pinned copy. To run a tree on purpose, set `YMIR_RUNTIME_DIR` to it.

## If it does not work

- `who` says `no arm is held`: nobody holds the helm; take it from a harness session.
- `armpin` is broken: run `bin/engine/runtime-deploy.sh`, then restart Rödd from the launcher.
- Rödd refuses to start: the line names the missing pin; deploy it first.

## CHANGE LOG

- **2026-11-12** — written with the change it describes (plans 254 and 257).

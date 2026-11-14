# engine · 2026-11-12 — the nightly update runs the update script, not a model

## Files
- `bin/agents/groa-agent/groa-agent.sh`: `GROA_MODE=script` (the default) runs `bin/agents/groa-update.sh` itself; a
  failed run exits non-zero and files a dated fault; the agent road stays behind `GROA_MODE=agent`, and an agent whose
  model is unavailable now counts as a failure
- `bin/agents/groa-agent/seat.sh`: Gróa is seated on the pinned runtime, not the working tree; OpenCode is only
  required in agent mode; the unit carries `GROA_MODE` and a one-hour start limit

## Why
The 04:10 timer did not run the update. It asked `opencode/nemotron-3-ultra-free` to type the update commands. That
model is gone. On heimdall and on nidavellir, every night from 2026-11-08 to 2026-11-12, the log read:

```
Error: Model unavailable: opencode/nemotron-3-ultra-free
── … tick finished (rc 0) ──
```

So no machine updated itself for at least five days, and systemd reported every run as finished. The tree the agent
worked in was also `~/ymir`, the operator's working tree, so even a successful run installed the apps where no icon
runs them (plan 275, part two).

## Fix
- An update is a fixed list of commands, so the timer runs the script. No model stands between the timer and it.
- The exit code is the update's own. A failure writes `$YMIR_HOME/hodd/state/groa/faults/<stamp>-nightly-update.md`
  with the machine, the tree, the exit code and the log's last lines.
- Gróa runs from `~/ymir-runtime` (or `YMIR_RUNTIME_DIR`), the tree the icons and units run.

## Proof
On heimdall, a tick through the new path ran `groa-update.sh` in the pin; the result is recorded in plan 275.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

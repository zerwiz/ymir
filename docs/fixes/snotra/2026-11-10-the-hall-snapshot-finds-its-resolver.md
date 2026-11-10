# The hall snapshot finds its resolver, and stops counting a queue that is not there

**2026-11-10 · component: snotra · `systems/snotra/services/cron/hall-snapshot.sh`**

A cron row that reports `rc=2` every night is a cron row nobody reads. This one had two faults
in six lines.

## Fault 1 — the resolver was looked for beside the script

```bash
_yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for _yc in "$_yr/hoard-lib.sh" "$_yr/../vault/hoard-lib.sh" "$_yr/../../vault/hoard-lib.sh"; do
```

The door sits five levels down in `systems/snotra/services/cron/`, and the resolver lives at
`bin/vault/hoard-lib.sh` in the tree. None of those three candidates exists, so everything below
died the same way:

```
hoard_settings_dir: command not found
hoard_local_env: command not found
hoard_state_dir: command not found
hoard_data_dir: command not found
YMIR_STATE_DIR: unbound variable
```

It now searches from `$ROOT` (which the script already computes), asks `ymir_home_root` for the
home, and refuses with a named remedy if the resolver is missing rather than half-running.

## Fault 2 — a read that looked like a failure

```bash
wake=$(wc -l <"$STATE/.wake-queue" ...)
```

The queue is created by whatever writes a wake, not by a snapshot door. Reading a missing file
printed `No such file or directory` into the cron log every night — a rung of noise in a log
whose whole job is to be trustworthy. A missing queue is a queue with nothing waiting: it is now
read only when it exists, and never created as a side effect.

## Proved

The door now runs end to end and writes its JSON: `hall-snapshot{generated_at,output,build_output}`
with `wake: 0` and the tally, errands, smiths and ledger keys present.

## CHANGE LOG

- **2026-11-10** — written, alongside the change. Found by reading the two `rc=2` cron rows in
  `runes_audit.md` (`bin/time/nornir-job-gna-mail.sh` is a addresses/DNS fault and belongs to the
  Allfather's Workspace, not to code).

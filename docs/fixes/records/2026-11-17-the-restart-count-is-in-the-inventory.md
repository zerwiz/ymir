## records · 2026-11-17 — the inventory carries the restart count, and the heart's estate is named and budgeted

### Why

Plan 003 (`$YMIR_HOME/hodd/machines/example-heart/plans/003-the-estate-named.md` §3) says a machine that cannot say
"What restarts, and how often" cannot say why it dies. `restarts.md` was written by hand because
`bin/records/running-inventory.sh` carried no restart column. The heart had 36 containers running, every one at
`RestartCount = 0`, and a unit at 46 restarts — and neither number was in any generated record.

### What changed

`bin/records/running-inventory.sh` — the measured record now carries, per container:

- `restart_count` (`docker inspect .RestartCount`), `last_exit_code` (`.State.ExitCode`),
- `last_started` (and `last_finished`, only when the container is not running),
- `last_error` — `.State.Error` when the engine recorded one, otherwise the first error-shaped line of the
  container's last twenty log lines, cut to 160 characters, so the loop's own sentence is in the record.

and, per unit, a new `units_restarts:` list beside `units_active:`: every service that is `running` **or** `failed`,
with `NRestarts` and its scope (`system` · `user`). `units_active` keeps its shape, so nothing that reads it breaks.

Two host lines were added for the budget work that needs them: `memory_available_mb` and `swap_used_mb`.
The markdown page gained a `restarts` column, and the closing line now says how many containers are restarting.

Two faults found in the first version, both fixed before it shipped:

1. `systemctl list-units --state=failed` prints a `●` bullet in the first column, so `awk '{print $1}'` handed
   `systemctl show` a unit literally called `●` and every count after it landed on the wrong name. The list is now
   filtered to real unit names (`grep -E '\.service$'`).
2. `systemctl show` does not promise property order — measured on the heart, it printed `NRestarts=` **before**
   `Id=`, so a line-at-a-time reader mispaired every count with the previous unit. A block is now collected whole and
   printed at its blank-line boundary.

### The estate it measured (the heart, 2026-11-17 13:20 EET)

`registry-audit.sh` reported **one** unnamed container, not twenty-five: `forgejo` — the heart's own older Forgejo,
in host network mode, answering 200 on loopback, with no row anywhere. The stacks the plan named on the same morning
(`mautic-*`, `postiz-*`, `supabase-*`, `temporal-*`, `immich-redis`) no longer exist on the machine at all — they were
stopped 2026-11-14 and removed since — so their rows stay (Rule 11) and are now marked as measured-absent.

`$YMIR_HOME/hodd/identity/services.yaml` gained, for all 36 running containers and the one exited one: image, compose
project, published ports, restart policy, `RestartCount`, last exit code, last error, the directory it belongs to, the
raise (compose file or `docker run`), an owner, a runbook, and a memory ceiling; plus a top-level `budget:` block whose
arithmetic is printed beside the rows. The ceiling rule is twice the resident memory measured that day, rounded up to a
32 MiB step with a 64 MiB floor, so the sum is reproducible by anyone with the same measurements.

### How it was proved

On the heart, with the new registry read through a throwaway `YMIR_HOME` so no other hand's home was touched:

```
REGISTRY AUDIT — 2026-11-17T12:20:46Z
running containers: 36   named entries in the registry: 63
== RUNNING BUT NOT NAMED (0) — each is a fault: write its entry, or stop it
   none — every running container is known
EXIT=0
```

and the inventory printed 37 `restart_count` lines for 37 containers (36 running + grafana exited), every one `0`, and
named the loop that does exist: `casaos` at `nrestarts: 46`.

### Limits, stated plainly

- A ceiling is a budget, not a wall: nine docker caps are looser than their budget (`calcom-app` 2,048 vs 928,
  `vexa-lite` 1,536 vs 288, and seven smaller ones) — 5,760 MB of wall against 928 MB of budget. Tightening a cap is a
  container recreate, which is a restart, so it belongs to the Allfather and to a window.
- `registry-audit.sh` still exits 1 on an unnamed container and nothing calls it on a clock; the caller is the
  supervisor in plan 004.
- Which of the 36 the heart should carry is the Allfather's decision; the registry names all of them and the budget
  block says so rather than guessing.

## CHANGE LOG

- 2026-11-17 — written with the change.

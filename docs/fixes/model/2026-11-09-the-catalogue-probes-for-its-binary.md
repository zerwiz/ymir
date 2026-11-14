# The catalogue probes for its binary instead of assuming a PATH

**2026-11-09 · component: model · `bin/model/catalog.sh`**

Found while auditing the near loop: the hall's window dial read `— tokens · auto-compact at —`
on this seat and on the heart. The dial was not the fault — `bin/seat/core-four.sh` was
reading the truth and being told zero.

## What was wrong

`bin/model/catalog.sh` called a **bare `pi`**. That is a promise that the caller's PATH is an
interactive one, and a service's is not: `hlidskjalf-gate.service` sets

```
Environment=PATH=%h/.bun/bin:/usr/bin:/bin
```

Neither install channel is on it — `pi` lives at `~/.npm-global/bin/pi` on a dev seat and at
the mise shim channel on the heart. So `pi --list-models` answered nothing, the
window fell to `0`, and the compaction thresholds fell with it. Measured, both seats, same
symptom, different channel: which is what made it a fleet fault rather than a local one.

## What it does now

```
catalog.sh --which-pi     # which binary answered, and by which channel
catalog.sh --check        # …and the count, naming the channel
```

The binary is resolved once, by channel: `PI_BIN` → `PATH` → the documented install
channels (`~/.npm-global/bin`, the two mise shim channels, a per-user bin directory,
`~/.bun/bin`, `/usr/local/bin`, `/opt/homebrew/bin`, `/usr/bin`). Nothing is
installed and no operator PATH, rc or npm config is edited — the same boundary
`bin/pi/pi-ensure.sh` drew on 2026-09-30. A `PI_BIN` that is not executable is refused
loudly rather than silently ignored.

## Proved

- `env -i PATH=/usr/bin:/bin bash bin/model/catalog.sh --which-pi` →
  `"/home/zerwizomar/.npm-global/bin/pi","probed","1.5.0"` (no shell had it).
- Same, `--check` → `PASS -> 449 models`.
- `PI_BIN=/nope` → refuses, exit 1, model "NOT IN THE CATALOG".
- The gate itself, restarted under the unit's own PATH, then answered
  `window 1000000, auto 500000, force 750000` where it had answered `0`.

## Guard

`bin/seat/tests/test_doors_fleet_path.sh` runs the catalogue and every near-loop door under
the gate's trimmed PATH — the fault class passes in a shell and dies under a unit, so the
test is deliberately not run in a friendly one.

## CHANGE LOG

- **2026-11-09** — binary resolution by probe with `PI_BIN` as the one documented override;
  `--which-pi` and a check line that names the channel (plan 229).

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the heart's user. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

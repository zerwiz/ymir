# Install & plan the host — what this machine will become, and where its things live

> **Purpose:** the host-side door to the install. Galdr's
> `assets/installation.md` is the map of every step; this page is what the
> *operator of the machine* needs: read the plan before anything changes, and know
> which root holds what.

## Read the plan before the install touches anything

The install no longer asks with a recited paragraph — it prints a plan **probed on
this host**, one row per step, each with its state and the reason for it.

```bash
bin/ymir-plan.sh                # the plan (TOON)
bin/ymir-plan.sh --blocked      # only what cannot proceed, and why
bin/ymir-plan.sh --json         # for automation
bin/ymir-install.sh --plan      # the same, through the installer's door
```

```
plan_states[5]{state,means}:
  "DO","a change will be made"
  "SKIP","already satisfied — nothing to do"
  "INFO","a fact about this host, discovered"
  "BLOCKED","cannot run — the reason names what is missing"
  "CONSENT","needs the operator's word"
```

A `BLOCKED` row is a fact, not a failure: the plan exits 0 and prints it. The
phase-1 `purity` row is the one to read first on a packaged install — it names
anything of the operator's left in the code tree.

## The home is the operator's to choose

A real interactive install asks once, and records the answer as machine state:

```bash
~/.config/ymir/home      # the home chosen at installation (a path)
```

Resolution order, always through `bin/hoard-lib.sh`:
`$YMIR_HOME` → the recorded choice → `$HOME/Documents/Ymir` (the one documented
default). `--check` never writes. `--yes` takes what is recorded, else the default.

To move an existing home to a new place, re-run the install with the new value:

```bash
YMIR_HOME=/path/to/new-home bin/ymir-install.sh
```

## The doors — what the operator types afterwards

Two commands land on PATH (`ymir`, `ymir-install`); everything else is a door on
`ymir`, named for the figure who does the work. `ymir --help` lists them all.

```
ymir raise | lower        lift the hall, or lay it down
ymir hlidskjalf | sessrumnir   the two windows
ymir smidja               the board on :8437 — build · start · stop · status
ymir heimdall [invite]    the way in, and letting someone else in
ymir eir                  what stands, and mend what does not
ymir groa [migrate]       take the latest, and mend this home forward
ymir mimir · sense · plan
```

## Both shapes — a clone and an npm install

The operator may have cloned the tree or installed the package; the scripts must
not care. `bin/app-lib.sh` resolves a surface either way (`apps/<surface>`, else
`node_modules/@zerwiz/<package>`), `bin/smidja-lib.sh` resolves the smithy, and
`bin/electron-lib.sh` verifies a shell's runtime. To exercise the *other* shape
without a second machine:

```bash
YMIR_ROOT_DIR=/path/to/an/npm/@zerwiz/ymir bash bin/app-lib.sh   # resolve against it
```

That variable is how a resolver is tested against a package from a clone.

## Which root holds what

```
roots[6]{root,resolver,holds}:
  "home","ymir_home_root","everything the operator owns"
  "hoard","hoard_root","docs · secrets · identity · tenants · memory"
  "records","hoard_data_dir","operator · fleet · machines · the host profile"
  "state","hoard_state_dir","pids · logs · locks · caches (ephemeral)"
  "settings","hoard_settings_dir","agents.yaml · cron.yaml · tailscale-sync · the wedge channel"
  "credentials","hoard_local_env","$YMIR_HOME/.env.local — auth, OAuth keys, tokens"
```

**The law:** the package is the **code that runs the programs**. Everything the
operator owns lives in the home. A packaged install replaces its tree on upgrade —
so anything of theirs kept in the tree is kept at its peril, which is exactly what
the plan's `purity` row exists to catch.

**Rule for a new host feature:** resolve every path through `bin/hoard-lib.sh`;
never name `$ROOT/data`, `$ROOT/state`, `$ROOT/config` or `$ROOT/.env.local`.

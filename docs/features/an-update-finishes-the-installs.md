# An update finishes the installs

## What it is

When you update Ymir, Gróa moves the code and then asks Eir, the healer, what is broken. Before this change
that was the end: the update said it was done, and the broken surfaces were left for you to find.

Now the update finishes the job:

1. Eir checks every surface.
2. Gróa asks Eir to **mend the safe ones**: Ymir's own files and units, on this machine, with no download and
   no root.
3. Eir checks again.
4. The **last line** of the update says either `whole`, or names each surface still owed with the exact command
   that mends it.

A surface that needs a download, root, or a change to something you chose yourself is never mended behind your
back. It is listed as owed, and you run its command when you are ready.

## What you need

- Ymir installed, and an update to run (`bin/agents/groa-update.sh`, or the scheduled update).
- Nothing else. The list of surfaces and who may mend each one ships with Ymir in `config/surfaces.yaml`.

## Do it

Run an update as you always have:

```bash
bin/agents/groa-update.sh
```

Read the last line. It is one of these:

```text
groa-update: whole — every surface answers
groa-update: NOT whole — owed: voice (ask), hnoss (safe); steps stopped at their limit: bilskirnir;
groa-update: the exact commands —
  voice: bin/agents/eir-doctor.sh fix voice
  hnoss: bin/agents/eir-doctor.sh fix hnoss
```

To see what is owed without updating, ask Eir. Each broken row now gives a reason, and the list ends with one
`owed:` line per surface:

```bash
bin/agents/eir-doctor.sh check
```

To mend one surface yourself, name it. Naming it is your word, so Eir mends it even if it is an `ask` surface:

```bash
bin/agents/eir-doctor.sh fix voice
```

To mend only what an update would mend on its own:

```bash
bin/agents/eir-doctor.sh fix --safe
```

### The three risk classes

| Class | Who mends it | Examples |
|---|---|---|
| `safe` | The update, unattended | re-seat Ymir's mail desk unit, start Ymir's own watcher, move a unit onto the pin |
| `ask` | You, by running the command | install a package, build an app with npm, anything that needs root |
| `never` | Nobody; it is reported only | a fault in code or upstream, or a choice that is yours to declare |

### When a surface is owed and you are fine with that

Some machines are meant to leave a surface unfinished. List it, one name per line, in your home:

```text
$YMIR_HOME/config/owed-accepted.txt
```

The update still names it in the last line, as `accepted as owed`, but it no longer counts as a failure.

### A unit that kept an old value

An update moves a unit's paths onto the pinned runtime, but it used to keep every other argument. So a unit
could keep running an old port long after its source changed. Eir's `unitdrift` surface finds such a unit:

```bash
bin/engine/units.sh drift                     # which units still run a retired value
bin/engine/units.sh write gna-desk --render   # re-seat one from its source
```

Only values the source has declared as retired count. A port or path you chose yourself with `--set` is never
called drift.

## Notes and limits

- **Exit codes.** `0` whole. `1` the seat could not be seated. `4` the code and the seat moved, but surfaces are
  owed or a step stopped at its time limit.
- **A stopped step is a failure.** If a step runs past its limit, the update goes on, but the last line names
  the step and the update exits 4.
- **A fault report.** When the owed list changes, Gróa writes one report to
  `$YMIR_HOME/hodd/state/groa/faults/`. While the list stays the same, she writes nothing new.
- **Not yet built.** Sending a worker to solve an owed surface, the scan of the models and services you already
  have, and starting an application that raises what it needs are later steps of plan 278.

## If it does not work

| What you see | What to do |
|---|---|
| The last line says `NOT whole` | Run each command it prints. Read `bin/agents/eir-doctor.sh check` for the reason on each row. |
| A `safe` surface is still owed after the update | Its mend ran and did not take. Run `bin/agents/eir-doctor.sh fix <surface>` and read the row again. |
| `a2abridge` is broken: "boots with multi-user.target" | Run `bin/bridge/a2abridge-ensure.sh ensure`. It repoints the unit at the user boot target and starts it. |
| `unitdrift` is broken | Run the `units.sh write <name> --render` command in the row. It restarts that one unit. |
| Eir says it has no register | The tree has no `config/surfaces.yaml`. Eir still checks, but treats every mend as `ask`. Update the tree. |

## CHANGE LOG

- **2026-11-12** — Opened with plan 278: Gróa mends the safe surfaces after the check, and the last line tells
  the truth.

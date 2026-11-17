# The service registry answers in one read

**What it is.** Every service the house hosts has a row in one file, and that row answers seven questions without a
hunt: what raises it, what file actually runs, what port it owns, which folder it lives in, which runbook to open when
it is down, whether stopping it is an incident, and what memory it may hold.

The file is `$YMIR_HOME/hodd/identity/services.yaml`. The door you read it through is
`bin/records/registry-audit.sh`.

**Why it exists.** On 2026-11-17 finding one service took four commands that each had to be guessed: a unit name, a
script path, a journal line and a port sweep. All four answers were facts the house already knew and the registry could
not say. Worse, one of them was a symlink into a directory tree that no longer existed — the service had died unseen
because nothing checked that the file a row names still exists.

## What you need

A home with `hodd/identity/services.yaml` in it, and `python3` with `yaml`. Nothing else: no service has to be running
for a row to be read.

## The commands

```bash
# one service, in one read — what raises it, what runs, port, dir, runbook, stop, budget
bin/records/registry-audit.sh --answer whiteboard

# every row's id, for when you know the service and not its row name
bin/records/registry-audit.sh --list

# the whole registry judged: ports, paths, sockets, shape, containers
bin/records/registry-audit.sh

# one line, for a cron row or a dashboard
bin/records/registry-audit.sh --quiet
```

`--answer` exits `0` when the row exists and `2` when it does not, naming the ids the registry does have so you are
never left guessing.

## What the check refuses

Four faults are red, and each finding names the registry file, the row and the field — never just a count:

- **a port owned twice** — two rows naming one port is a fault, because two doors on one number is how one of them dies
  quietly;
- **a path that does not exist** — a row whose `script` or `dir` is gone. A symlink whose target was deleted is named as
  that, with the target it points at;
- **a listening door no row names** — a socket this machine answers on (on anything except loopback) that no row claims;
- **a row that does not fit the shape** — a missing field is a finding, never a pass. An unset `criticality` is the
  clearest case: "nobody has decided whether a stop is an incident" is not an answer.

## Limits — said out loud

- **Only on the machine a row names.** Paths and sockets are measured where the row says they live. A row for another
  host cannot have its paths stat'd from here, so the audit **skips and says so** rather than guessing. Run it on the
  machine the rows name.
- **Loopback is not a door.** The halls listen on `127.0.0.1` and are reached from the desktop session, so a loopback
  socket is not a hosted service and is not judged.
- **The shape is enforced, not populated.** A row that misses a field is reported, never filled in with a guess: the
  registry must not carry a value nobody measured.
- **This is not a supervisor.** The audit reads; it never restarts, stops or raises anything.

## If it does not work

| what you see | what it means |
|---|---|
| `no registry at …` | the home holds no `hodd/identity/services.yaml`, or `YMIR_HOME` points somewhere else |
| `the home could not be resolved` | `bin/vault/hoard-lib.sh` cannot find the home — check `YMIR_HOME` |
| `no row with id 'x'` | `--answer` was given a name the registry does not use; `--list` prints the ones it does |
| `SKIPPED — a path exists` | you are on a machine no row names: the paths belong to another host and were not measured |

The row shape itself is `config/services.schema.json`, and the registry declares it in its own `schema:` header — so the
next hand writes rows that fit without reading a plan.

## CHANGE LOG

- **2026-11-17** — the page was written (plan 312): the registry answers in one read — unit, script, port, dir, runbook and budget per service — and the two checks that keep it true.

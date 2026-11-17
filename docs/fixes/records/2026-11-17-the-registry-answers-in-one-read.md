# 2026-11-17 — the registry answers in one read

**Component:** records (`bin/records/registry-audit.sh`, `config/services.schema.json`, the shape of
`$YMIR_HOME/hodd/identity/services.yaml`).

**Plan:** 312 — the registry answers in one read.

## What was wrong

Hunting one service on 2026-11-17 took four commands that each had to be guessed: `systemctl --user cat` for the unit,
`find` for the script, `journalctl` for the reason it exited, and a port sweep to guess which number it might own. All
four are facts the house already knew. The registry knew a service existed and could not say where its hands were.

The concrete cost: a share door had been raising itself 39,803 times, because its `ExecStart` pointed at a symlink into
a directory tree that no longer existed. An audit that checked that `script` still exists would have caught it the day
the target was deleted, and no check did.

## What this change adds

**The row shape**, one shape for every entry, written into the schema, into the registry's own header, and into the
Galdr asset that governs the registry (`.agents/skills/galdr-ymirsystem/assets/registry.md`):

| field | answers |
|---|---|
| `unit` or `compose` | how it is raised — the door to restart it |
| `script` | the file that actually runs, resolved, never a symlink into a dead tree |
| `ports` (`port` for one) | the number it owns |
| `dir` | the kit directory the runbook's `cd` needs |
| `runbook` | the page to open when it is down |
| `criticality` | whether a stop is an incident (`always` · `wanted` · `dormant`) |
| `budget` | the memory it may hold |

`budget` is read in **plan 003's shape** (the heart estate, which writes those rows): the measured block
`{measured_mb, memory_ceiling_mb, residency}`, with a bare systemd size (`96Mi`) accepted as the shorthand of the same
fact. Two spellings of one truth, and never both at once.

**Two checks that make the shape true**, in `bin/records/registry-audit.sh`:

1. **A port is owned once.** Two rows naming one port is a fault (named by port and by both rows), and a listening door
   this machine answers on — on anything but loopback — that no row names is a fault (named by address and port).
2. **A path exists.** A row whose `script` or `dir` does not exist is red, and a symlink whose target is gone is named
   as that, with the target it points at.

Plus the shape itself: a field the schema requires and a row does not carry is a finding, never a pass. **The strict
reading was applied**, which is the rule this change holds to: an unset `criticality` is a finding, because "nobody has
decided whether a stop is an incident" is not an answer.

**One read for one service** — `registry-audit.sh --answer <id>` prints how it is raised, what runs (and whether the
file exists), the port it owns, the folder, the runbook (and whether the page exists), whether a stop is an incident, and
its budget. `--list` prints the ids; `--quiet` is the one line a cron row or dashboard wants.

**The machine's own boundary is honoured.** `script`, `dir` and the sockets are measured only on the machine a row
names — a path on another host cannot be stat'd from here, and a guess is worse than a named skip. On a machine no row
names, the audit prints a `SKIPPED` line that says so and why, and never a false green. The container-coverage check is
scoped the same way: `docker ps` describes this machine, so comparing it against a registry written for the heart is a
comparison of two different machines, and it said so.

## What it printed

The proof is `tests/test_registry_answers.sh` — every case in a throwaway home, never against the live registry:

```
ok   a registry that fits its shape is green (exit 0)
ok   the report says green
ok   two rows on one port is red (exit 1)
ok   the finding names the port and both rows
ok   a missing script is red (exit 1)
ok   the finding names the row and the path
ok   a broken symlink is named, with the target it points at
ok   an unset criticality is a finding, not a pass
ok   a listening door that no row names is a finding, named by address and port
ok   --answer exits 0 for a row that exists
ok   the one read answers: raises
ok   the one read answers: runs
ok   the one read answers: port
ok   the one read answers: dir
ok   the one read answers: runbook
ok   the one read answers: stop
ok   the one read answers: budget
ok   an unknown id is refused, with the ids it does have
ok   --quiet is one line, and green is 0
ok   --quiet is one line, and red is 1
all registry-answers cases passed
```

Against the live registry the audit is **red, and honest about why**: 24 rows, two ports owned twice (`8485` by `board`
and `proxies`, `16585` by `code` and `forgejo-hostinger`), and the rows that do not yet carry the shape. Those values are
**not invented here** — naming the 36 containers and setting a budget per service is plan 003's errand, and inventing
them would make two truths. This change writes the shape, the check and the door; the rows arrive from the hand that
measured them.

## What is owed

- **The rows.** `unit` (or `compose`) and `dir` are still missing on most rows; `script` on those without a compose
  file. The audit names every one, by row and by field, which is the worklist.
- **`runbook`** is unset on a few rows; each needs the page that answers when it is down.
- **The two shared ports** — `8485` (`board` and `proxies`) and `16585` (`code` and `forgejo-hostinger`) — are real
  faults the audit now names. Whether the Proxies row should name a port the Board fronts, and which of the two
  Forgejos stands, is the Allfather's to settle (plan 312 §4, plan 003).

## CHANGE LOG

- 2026-11-17 — review-mend: added missing heading for #814

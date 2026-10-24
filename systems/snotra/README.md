# Snotra — the meeting system

Snotra hears a meeting, writes its record, mines the decisions and the actions, boards them, letters the
participants, and takes the operator's word before a letter leaves. It runs whether or not anyone watches, and it
owns records: **it is a system, not an app** (plan 129 §12). There is no screen of its own; Hlidskjalf and Óðrerir
may read what it wrote.

Keeper: **Snotra** — the wise one of Ásgarðr. What it may write, what it may ask, and what it may never touch are
declared beside this file in [`domain.yaml`](domain.yaml), which is the authority for anything below that disagrees
with it.

## The shape

```
systems/snotra/
├── README.md              this file — what it is and how it is called
├── domain.yaml            keeper · board · memory · services · doors · bounds · policy
├── services/              the RUNNING parts, one folder per service (a service is a process, not a shelf)
│   ├── ear/               hearing: the watch, capture, transcription, the live tail, the voice, container/
│   ├── record/            the record contract every transport writes through
│   ├── letters/           the letters out, rendered from the record
│   ├── approve/           the operator's word bound to the exact bytes of a letter
│   ├── mail-watch/        who answered (read-only)
│   ├── cron/              scheduled maintenance, the boards and the projection
│   ├── tts-lease/         the voice's lease on the rail
│   └── calendar/          Mánagandr's read door and the one calendar write door
├── systems/               its own records' shapes and templates — the contracts the code enforces
├── memory/                its curated notes (the episodes live in the well: `domain:snotra`)
└── tests/                 its own gate
```

## How it is called

Every door is a CLI. Two ways, both real:

```bash
# the canonical path (what new code and the schedule should name)
systems/snotra/services/ear/snotra-detect.sh --help
systems/snotra/services/letters/snotra-letter.sh render <meeting-dir>
systems/snotra/services/approve/snotra-approve.sh check <meeting-dir>
systems/snotra/services/cron/snotra-cron.sh digest

# the retired path — one flat shim per door, kept at its old name, execing the new door above:
bin/time/snotra/snotra-detect.sh --help          # → systems/snotra/services/ear/snotra-detect.sh (see "The move")
```

The doors are named in `domain.yaml` under `services:`; that list is the index, and this README does not repeat it
door by door.

## The move — 2026-10-24, plan 129

The code lived in `bin/time/snotra/` — 75 files on a *time* shelf, which is a filing convenience, not an
ownership. Plan 129 §18 changed the axis: **a domain is the primary folder; a layer is a folder inside it.** So
`bin/time/snotra/` became `systems/snotra/`, grouped into the eight services above, and `bin/time/` keeps only the
time doors and the Nornir jobs.

Nothing was deleted (Rule 11 — everything moved). Four instruments carry the move, and all four are required:

| instrument | what it does |
|---|---|
| `.agents/paths-ledger.yaml` | records the move: `bin/time/snotra/` → `systems/snotra/`, date, why, migration |
| `.agents/migrations/0014-systems-shelf.sh` | heals an existing home idempotently: repoints `config/cron.yaml`, the home's docs and the installed units |
| `bin/time/snotra/<door>` | a one-line shim per door: execs the new door, says the move on stderr |
| `bin/gates/guards/path-ledger-guard.sh` | refuses a shipped file that still spells the old path |

The shims are **retired by a dated follow-up**, never silently: see
`docs/fixes/snotra/2026-10-24-snotra-becomes-a-system.md`. A shim exists so a caller nobody has repointed yet
still works; it is not a home.

## What this system is not

- **Not an app.** No UI, no build of its own. It may be *read* by an app.
- **Not a tool shelf.** Its doors are `systems/snotra/services/<service>/<door>`, not `bin/`.
- **Not a shared kit.** It asks the clock, the vault, the well and the ledger — it does not own them.

## Checks

```bash
bin/gates/guards/path-ledger-guard.sh check                     # no stale reference to the old path
systems/snotra/tests/smoke.sh                                   # the pipeline's own gate
.agents/migrations/0014-systems-shelf.sh                        # heals this home; a second run rewrites nothing
```

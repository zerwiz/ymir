# hoard · unversioned · 2026-11-20 — the code stops naming the retired home paths: the resolver answers, three passes, one shelf each

Plan 331.6 and 331.8, built. The predecessor (`…2026-11-19-the-home-shape-every-install-gets.md`) gave the
home four shelves, moved every seat with migration `0026`, and left the one-cycle links so that thousands of
existing files kept working. This is the other half: the code that NAMED the retired paths now asks the one
resolver instead, so a home with the links removed is read correctly.

## Why

Migration `0026` left `hodd/life -> ../life` and `hodd/state -> ../state`. Those links are a compatibility
shim with one release of life in them. The repository still spelled the old paths in 62 files under `bin/`
alone — and more in `systems/`, `apps/`, `src/` and the two harness tool shelves:

- a reader that named `hodd/life/meetings` worked **only** because the link existed;
- the day the links are retired, every one of those readers goes dark at once, in the middle of a release;
- and the retired-path gate (331.9) only stops a NEW file teaching them, so the old spelling would have
  survived in the tree for years.

The plan is explicit about the shape of the fix. It is not a rewrite of 36,000 files; it is **the resolvers
change, and everything else inherits** (331.6), and the rewrite happens **in passes, by shelf, guarded**, each
pass reporting what it changed and what it could not resolve (331.8).

## What

### The resolver (first, because everything asks it)

**`bin/vault/hoard-lib.sh`** — the one resolver — learns three things:

| Addition | Answers |
|---|---|
| `hoard_life_dir <var>` | the operator's own shelf: `$YMIR_LIFE_DIR` → `<home>/life` |
| `hoard_shelf <var> <life\|state\|config\|record>` | any of the four shelves, by name; an unknown name is a refusal (exit 2), never an invented directory |
| `hoard_life` · `hoard_state` | the same two shelves as a **value on stdout**, for a single site inside a longer argument |

`hoard_state_dir` already existed and was already `<home>/state`; the fault was that callers did not use it.

**`bin/records/home_shelves.py`** (new) — the Python face of the same resolver. `shelf("life")`,
`shelf("state")`, `shelf("config")`, `shelf("record")` ask `hoard-lib.sh` in a subprocess (cached per
process), so a Python door and a shell door cannot answer differently. A module that spells a path instead is
now the exception, not the rule.

### Three passes, one shelf per commit, each guarded

Each pass was preceded and followed by `bin/gates/guards/retired-path-guard.sh`, and each pass used a plain
grep as its work-list, so the count is measured rather than claimed.

| Pass | Retired path | Files changed | Occurrences of the retired path, before → after | Where |
|---|---|---|---|---|
| 1 | `hodd/life/` → `life/` | 62 | 152 in 66 files → 38 in 20 | voice, day, dispatch, gimle, records, ward, doc-sweep, the Snotra services, the whiteboard saves shelf, both harness placement shelves, Hlidskjalf |
| 2 | `hodd/workspaces/<topic>/` → `life/<topic>/` | 23 | 24 in 16 files → 20 in 15 | Hlidskjalf (meetings discovery), the Snotra minutes door, Maestro, the lifecycle smoke, the voice draft shelf |
| 3 | `hodd/state/` → `state/` | 125 | 277 in 135 files → 29 in 15 | 80 shell doors, 20 Python modules, Hlidskjalf and Rödd's server, the Skirnir services, the calendar reader, the config examples and the docs |

The "after" column is not a residue of unfinished work: every one of those occurrences is on the deliberate
list below, and the count is measured with the guard's own exclusion set, so the number the next hand measures
is comparable. Nothing was "unresolved" in either pass — see below.

What "could not resolve" means in this table: a site the resolver cannot express. There were none, because
both shelves are a fixed place inside a home the resolver already returns. Where a script carried no resolved
home at all it now asks `hoard_state_dir`; where it carried one, the home stays the resolver's answer and only
the shelf segment changes. `bin/bridge/constellation.sh` composes its key shelf from the hoard root, so it
learned `hoard_state_dir` explicitly — that was the one place where hoard-root-plus-`state` produced the
retired path without spelling it.

### What is deliberately left naming the old paths

A record is never rewritten (Rule 06), and a detector must be able to name what it refuses. These keep the
old strings, each on a line that says why:

- `docs/fixes/` — history, exempt by the guard's own rules;
- `RULES/` — the law, append-only;
- `.agents/migrations/` — the migration that moves the paths, which cannot work without naming them;
- `bin/gates/guards/retired-path-guard.sh` and its test — the gate and its subject;
- `hodd/identity/home.yaml.example` — the register of retired paths;
- `src/ymir_runtime/library.py`, `systems/snotra/.../snotra_paths.py` — tolerated legacy readers, marked
  `retired-path-ok:`;
- Eir's `hoard` surface — it must CREATE and NAME the retired location to refuse a home that still has it.

## The proof

**`bin/gates/tests/test_four_shelves.sh`** (new) builds a temp home in the four-shelf shape with **no
compatibility link at all**, and asks the three doors the operator named:

```
$ bash bin/gates/tests/test_four_shelves.sh
  ok   the fixture holds no compatibility link: no retired old shelf, no state link
  ok   todos.sh reads HIS list off the life/ shelf
  ok   todos.sh reads the ledger off the state/ shelf
  ok   day.py reads HIS list off the life/ shelf
  ok   eir-doctor finds a four-shelf home clean
  ok   eir-doctor still refuses the operator's material left inside the record
test_four_shelves: 6 passed, 0 failed
```

Because the fixture has no links, a door that still named a retired path could only answer `unable`, and the
test would say so. The last assertion keeps the detector honest in the other direction: Eir must still refuse
a home that left the operator's material inside the record.

The suites that own the changed doors were re-run and pass: `test_todos_digest` (14), `test_todo_write_race`,
`test_comms` (18), `test_dispatch` (51), `test_snotra_store` (20), `test_snotra_ladder` (24),
`test_snotra_sensitive` (10), `doc-sweep` (every law held), `mocks-scan`, `test_constellation` (27),
`test_review_seats` (14), `test_runtime_deploy_stable` (10), `test_everything_up` (30), the mail suite (107),
`test_week_passes` (40), `test_voice_idle` (6), `test_broken`, `test_retired_path_guard`.

Two suites fail in this worktree both before and after this change, on a missing `.pi/extensions/` and on
Herðr's own stand-in: `context-left.test.sh` and `test_rodd_helm.sh`. They are environment faults, not this
change, and they are named here rather than hidden.

## Boundaries held

- **Nothing was deleted.** A retired reference is a change of answer, never a removal of a feature.
- **`docs/fixes/` and `RULES/` were not touched** — the record of what was believed stays.
- **One fix note**, this file, for the three passes.
- Nothing was pushed: the batch is gathered by the helm, one PR for all four errands of the hour.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #842

## hoard · 2026-10-01 — the shelf-sweeper finds the documents and proposes where each belongs

**Plan 63.** `bin/gates/doc-sweep.sh` — three verbs, in this order, because the order is the law.

```
doc-sweep.sh scan  [root …]         # REPORT ONLY — classifies, proposes, writes nothing else
doc-sweep.sh apply --plan <file>   # moves ONLY the MOVE lines of that plan; idempotent
doc-sweep.sh verify [--plan <file>] # re-checks BY NAME that every applied file is where the plan said
```

### Why

The operator's documents do not live in the vault. On 2026-09-30 the root beside the
home held **64 loose files and 8 directories** — `agent.c`, `raw.odt`, `CPU.txt`,
`blogs`, a bookmarks dump, a plans folder — and not one of them was named for a
shelf. A human moved them, or a tool dumped them. Naming them is judgement, not a
loop, so the first run must be a **report**, and the moving must be a **plan a human
read**.

There is no `--force` and no `--all`, and there is no "put it somewhere sensible".
That absence is the feature: a machine that can tidy on its own will eventually
tidy something it should not have.

### Classification — by evidence, in this order

1. a path naming a **known project** in `hodd/identity/projects.yaml` → that
   project's shelf (`svartalfaheim/<realm>/projects/<id>/`);
2. a plan-shaped or numbered-plan document → the **plan ledger**,
   **PROPOSED only** — a machine never files into the ledger;
3. a note carrying a **known domain** (`marketing · personal · work · meetings`) →
   `hodd/life/<domain>/` (the post-62 names; the retired ones are not learned);
4. anything else → **unplaceable**, reported with the reason it could not be
   placed. An unplaceable file is never dumped into `docs/`.

Before those four, one **ward**: an item that is not a document — a symlink, a
socket, a device, a binary, an archive, a credential by name, an OS folder, the
vault itself — is REPORTED and never moved, whatever its name looks like. On the
measured root that ward alone held 5 credentials, 4 archives, a symlink, two
husks of the vault, and the vault.

### The wards, and how each is proved

| Ward | How it holds |
|---|---|
| **Nothing moves without a word** | `scan` writes no file but its report; `apply` reads the PLAN for what to move, never the filesystem. There is no flag that skips the plan. |
| **The repo stays clean** | every destination must resolve inside the home, read through the one resolver (`bin/vault/hoard-lib.sh`) — never a literal. A plan line aimed at the code tree is refused by name, with the reason. |
| **All or nothing** | every line of a plan is pre-flighted before any move; one bad line refuses the WHOLE plan. A half-applied plan is worse than none. |
| **Never delete** | a symlink, an archive and a credential are refused even when a plan names them; a duplicate is reported as a duplicate, never resolved by removing one; a line that would overwrite is refused. |
| **A machine never files into the ledger** | ledger destinations are emitted as `PROPOSE`, and `apply` skips them. Only a `MOVE` line the Allfather wrote moves. |
| **Staging by name** | the script stages nothing and prints "stage by NAME — never `git add -A`" with the paths it moved (Rule 06). |
| **The report covers everything** | the tally is checked against the item count; a report that covers 76 of 81 items is refused rather than printed. |

### The four defects the build found in itself

- **Every file claimed the project `ymir-home`.** The project match asked "does the
  path contain the id's words", and every path on this machine contains `ymirhome`
  → tokens `ymir` + `home`. Evidence is now a **contiguous run of tokens** equal to
  the id: a folder the path merely passes through is not evidence.
- **A `case` pattern does not word-split.** `case "$b" in $DOC_CONTAINER` tested the
  whole list as ONE pattern, so every `.pdf` and `.odt` was reported as "not a
  document" — the exact misreading the plan warns about (a `raw.odt` IS a
  document). The lists are walked as words now.
- **A date is not a plan number.** `2026-09-30-marketing-notes.md` matched
  `^[0-9]{1,4}[-_]` and was proposed to the plan ledger as plan 2026. A leading date
  is stripped before the plan test.
- **A shelf proposed itself into itself.** Scanning `hodd/life/` offered to move
  `marketing/` to `hodd/life/marketing/marketing`. An item already standing on, or
  inside, its own destination is now reported **in place**.

### Idempotence and the ledger

`apply` writes one JSON line per move into `$YMIR_HOME/state/doc-sweep/applied.jsonl`
(from `hoard_state_dir` — state, never the code tree). A second `apply` reports every
line as `noop` and moves nothing; `verify` re-checks each recorded destination **by
name and by digest** (`sha256` for a file, a sorted tree listing for a directory) and
exits non-zero if any is missing or changed.

### Verified on the Allfather's own root (2026-10-01)

`bash bin/gates/doc-sweep.sh scan ~/Documents` covered **all 81 items** (64 loose files, 16
directories, 1 symlink) with a reason per line, and the root was byte-identical
afterwards — `find ~/Documents -maxdepth 1 | sort | md5sum` = `7714ce5a…` before and
after. Tally: 1 move, 3 propose, 64 unplaceable, 8 report, 5 hold.

The refusals were proved against that real report, not a fixture: a plan line aimed
at the worktree (`→ …/.yggdrasil/doc-sweep/docs/…`) is refused with
`OUTSIDE the home`; the real `Personal control.html` line re-aimed at the repo is
refused the same way; a plan naming the root's symlink, and one naming
`Gittoken.txt`, are both refused — and after all four attempts the root was still
byte-identical.

**No file of the Allfather's was moved.** The one MOVE line the report proposes is
`Personal control.html` → `hodd/life/personal/`, and it waits for his word, which is
the whole point of the tool.

### Files

- `bin/gates/doc-sweep.sh` — the sweeper (new)
- `.agents/tests/doc-sweep.test.sh` — 28 assertions over synthetic fixtures only
  (a temp home, a temp root, names that exist nowhere else)
- `docs/Architecture.md` — §3.14, the component's own entry

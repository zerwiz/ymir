# How a project is handled — one door to every project's rules

## What it is

Your project registry (`$YMIR_HOME/hodd/identity/projects.yaml`) has one row per project. Each row can carry a
`handling:` block that answers, in one read, the questions a worker would otherwise guess:

| Question | Field | Example value |
|---|---|---|
| Is it public? | `visibility` | `public` · `private` · `no-remote`, read from the forge |
| Where do its plans live? | `plans` | `repo` `plans/`, or `home` and a ledger path |
| Which board? | `board` | `plane`, `trello`, `github` or `none`, with the write right |
| Who works on it? | `people` | collaborator ids and roles |
| Is it private to the operator? | `private_to` | his id, empty, or `OWED` until he says |
| Who merges, under what gates? | `delivery` | `judge-merges` · `person-merges` · `operator-merges` … with CI and checks |
| Where and how does it deploy? | `deploy` | the machine, the script, and whether it needs his word |
| Which vault keys? | `secrets` | key **names** only |

Fourteen more fields are optional (environments, domains, data class, licence, scanning, keepers, toolchain and
others). Every value names its `source`. A value nobody could read says `unmeasured`, and a value only the operator
can give says `OWED`.

## What you need

- A home with a project registry. The door finds it through `bin/vault/hoard-lib.sh`.
- `python3` with PyYAML. With `jsonschema` installed, the audit also checks every value against
  `config/projects.schema.json`.

## The commands

```bash
bin/records/project.sh my-app                      # the whole handling block
bin/records/project.sh my-app --field delivery     # who merges, and the gates
bin/records/project.sh my-app --field delivery.road
bin/records/project.sh --list                      # one line per project
bin/records/project.sh --audit                     # rows missing visibility, plans or delivery; exit 1 on any
bin/records/project.sh --page > projects.md        # one table for people, a column per question
bin/records/project.sh --registry ./fixture.yaml --audit   # any other registry
```

## Limits

- The door reads the registry; it does not measure it. Filling the block from GitHub, the boards and the deploy files
  is a separate step, and each value says where it came from.
- `handling.delivery` is separate from the older top-level `delivery:` switch. The shipper still reads the top-level
  switch until it is taught the new block.

## If it does not work

- *"the home could not be resolved"*: set `YMIR_HOME`, or pass `--registry PATH`.
- *"no project …"*: run `project.sh --list` for the ids. A row's `name` and `aliases` are also accepted.
- *A schema finding*: the line names the row and the field. Fix the value in the registry, then audit again.

## CHANGE LOG

- **2026-11-21** — the page was written (plan 345): one door reads how every project is handled, audits the rows and renders the page.

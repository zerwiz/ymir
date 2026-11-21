## records · unversioned · 2026-11-21 — one registry answers how every project is handled

### Why

Workers kept learning how a project is handled by reading its repository and guessing. They guessed whether it is
public, where its plans live, which board it uses, who works on it, and who may merge. Some guesses were wrong: a judge
approved a pull request in a repository whose own rule says only a person merges, and had to stop by hand. The project
registry in the home already had a row for every project, but almost nothing in it answered these questions.

### What

- **`config/projects.schema.json`** is the shape of a new `handling:` block on each row of the home's project
  registry. It holds eight questions (plan 345): `visibility`, `plans`, `board`, `people`, `private_to`, `delivery`,
  `deploy` and `secrets` (key names only). It also leaves room for plan 346: `repos[]`, `placement`, and fourteen
  optional fields (`environments`, `domains`, `data_class`, `models_allowed`, `licence`, `upstream`, `scanning`,
  `backups`, `costs`, `clients`, `access`, `keepers`, `lifecycle`, `merge_account`, `toolchain`, `monitoring`).
- Every measured value carries `source:`, which says where it was read. A value nobody could read is `unmeasured`. A
  value only the operator may give is `{status: OWED}`. A guess is never written.
- The block sits **under** `handling:` so that the older top-level keys keep their meaning: `board:` is still read by
  plan-sync, and `delivery:` is still read by the shipper.
- **`bin/records/project.sh`** is the reader:
  - `<id>` prints the whole block;
  - `<id> --field f` prints one field, and dotted paths such as `delivery.road` also work;
  - `--list` prints one line per row;
  - `--audit` names every row missing `visibility`, `plans` or `delivery`, plus every schema finding, and exits 1
    when there is one;
  - `--page` renders the Markdown page for people.

### Proof

`bin/records/tests/test_project_registry.sh` runs on a fixture registry with invented names and passes 15 of 15. It
proves the door can:

- read a field and walk a dotted path;
- find a row by its name;
- keep OWED as OWED;
- fall back to a top-level key;
- fail on a missing field or an unknown project;
- audit what is missing and name a road outside the schema by row and field;
- pass a whole registry;
- render the table and the fourteen.

Against the home's own registry, filled the same night, `project.sh --audit` reports 81 rows, **0 without
visibility, plans or delivery**, and 0 schema findings.

### Not done here

The doors that should read the registry are plan 345.3, 345.4 and 346.8–14. They are the judge, plan-sync, the board
doors, the vault seed and the wards. They are separate errands.

## CHANGE LOG

- 2026-11-21 — written with the change (plan 345.1).

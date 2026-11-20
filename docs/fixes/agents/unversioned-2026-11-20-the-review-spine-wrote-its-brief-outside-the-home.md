## agents · unversioned · 2026-11-20 — the review spine wrote its brief outside the home, so every judge was refused

**Cites:** `bin/agents/eindri-review-spawn.sh:170` (and `:214`, the PR-only mode) ·
`bin/agents/einherjar-spawn.sh:96–160` (the split guard that rightly refused).

### Why

A review judge is seated by `bin/agents/eindri-review-spawn.sh`, which writes the fierce
brief, then hands the errand to `bin/agents/einherjar-spawn.sh` with `BROKK_DATA_OVERRIDE`
set to the shelf it chose.

It chose that shelf from the **code checkout**:

```bash
SHARED_ROOT="$PROJECT"        # the project path recorded in the task's meta
SHARED_DATA="$SHARED_ROOT/data"
```

`PROJECT` is the repo root the errand worked in. So the spine created
`<checkout>/data/<id>-review/`, wrote the brief there, and passed that path on as the
override. `einherjar-spawn.sh` resolves the house through `bin/vault/hoard-lib.sh` and
refuses any data shelf outside the operator's home — correctly, and with the right words:

```
error: the house is split — data resolves outside the home.
  data: <checkout>/data
  home: <home>
```

Every review judge on a developer seat was refused this way. The records the helm saw
show it four times on 2026-11-20, and each time the folder was moved home by hand.

Two faults were stacked, and the second is what hid the first:

1. The spine derived the operator's records from the code root, which Rule 04 forbids —
   a brief is a record, and no record lives in the public tree.
2. It created the directory **before** the spawn, so the spawn's refusal left a real
   `data/` folder beside the code — the split made visible, and left behind.

The PR-only mode carried the same fault in its own line, with the same consequence.

### Fix

`bin/agents/eindri-review-spawn.sh` now resolves the data shelf through the **same door**
`einherjar-spawn.sh` uses, once, beside the state resolver it already called:

- `YMIR_HOME_ROOT_RESOLVED` and `DATA_SHELF` come from `ymir_home_root` and
  `hoard_data_dir` (`bin/vault/hoard-lib.sh`), so the two doors cannot disagree about
  where the records live.
- `house_data <result-var>` is the one way in. An incoming `BROKK_DATA_OVERRIDE` may
  **move** the shelf inside the home — a seat that keeps its own data still works — but a
  shelf outside the home is refused aloud (`review-spawn: BROKK_DATA_OVERRIDE=… lies
  outside the home …`) and the home's shelf is used instead.
- There is no fallback to `<checkout>/data`. When no shelf resolves, the spine refuses,
  names the home it looked for, and creates **nothing** — a home that cannot be read is
  not a licence to write beside the code.
- Both sites were mended: the ordinary task path and the PR-only path.

### Proof

`tests/test_review_spawn_data_home.sh` (new, and named in `tests/run.sh`), on a throwaway
home and a throwaway checkout:

```
ok    case 1: the brief exists at <home>/hodd/data/spine-fixture-review/brief.md
ok    case 1: NO data folder inside the code checkout
ok    case 2: the override outside the home was refused aloud
ok    case 2: the checkout stayed clean
ok    case 3: a spine with no resolver refuses (exit 1)
ok    case 3: no data folder inside any checkout
13 passed, 0 failed
```

The test bites: run the same case against the pre-fix script (`git show HEAD:`) and it
prints the brief at `<checkout>/data/fx-review/brief.md`, leaving `<home>/hodd/data`
empty — the exact fault, reproduced.

```
$ bash tests/test_review_spawn_data_home.sh ; echo "EXIT=$?"
13 passed, 0 failed
EXIT=0
```

### Files

- `bin/agents/eindri-review-spawn.sh` — the data shelf resolves through the home; an
  override outside the home is refused aloud; no `<checkout>/data` fallback.
- `tests/test_review_spawn_data_home.sh` — the test (new).
- `tests/run.sh` — the test is run with the rest.

### Not done, and named here

`bin/forge/review-mend.sh:120` still reads `$ROOT/data/$_id/brief.md` when it seats a
fixer. That is the same class of fault — the code root used as the records shelf — but it
is a read in a different door, it is outside what this errand names, and changing it here
would put two behaviours in one change. It waits for its own note.

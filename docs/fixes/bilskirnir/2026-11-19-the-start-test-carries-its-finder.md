## bilskirnir · 2026-11-19 — the start test's fake tree carries what start.sh sources

### What was wrong

The hall's own test of `start.sh`, `tests/start-owns-ports.sh`, failed on `main` (`7a546ae`). Four of its eleven
cases failed with `scripts/ymir-root.sh: No such file or directory`.

### The cause

The split taught `start.sh` to source `scripts/ymir-root.sh` and to run `scripts/data-home.sh`. The test builds a fake
app tree by copying `start.sh` alone, so neither script was there.

### The fix (in `zerwiz/bilskirnir`, commit `8127a55`)

The fake tree now carries a copy of `scripts/ymir-root.sh` and a stub `scripts/data-home.sh` that exits 0. The stub
matters: the real script links the tree to the operator's data home, and a test must never do that.

### Proof

`bash tests/start-owns-ports.sh` → 11 of 11 `ok`, exit 0. It was 7 of 11 on `main`.

### Owed

Push `zerwiz/bilskirnir`. The commit is on the local branch `eindri/e2e-bilskirnir` in the apps home's clone, beside
the two fixes of the same day.

## CHANGE LOG

- 2026-11-19 — written.

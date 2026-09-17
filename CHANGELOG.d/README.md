# CHANGELOG.d — pending changelog entries

Add **one file per change** here. `bin/changelog-assemble.sh` folds them into
`CHANGELOG.md`, newest first, above everything already recorded.

## Why fragments instead of editing CHANGELOG.md

`CHANGELOG.md` is one file, and every branch appends at the same position — the
top. Git sees two branches inserting different lines at the same spot and calls
it a conflict, so every merge re-conflicts every open branch. Sixteen open PRs
were each resolved by hand for this reason alone.

A fragment is a **new file with a unique name**, so two branches never touch the
same one and the collision cannot happen. That is the whole point.

## Write one

Name it `<YYYY-MM-DD>-<slug>.md` and begin it with its dated heading:

```
CHANGELOG.d/2026-09-17-every-figure-loads.md
```

```markdown
## 2026-09-17 — every figure loads

- **The bug.** Twenty profiles existed; three loaded.
- **The fix.** The directory OpenCode reads is plural.
```

The file's contents are the entry **exactly as it should appear** in
`CHANGELOG.md`. The assembler copies it verbatim — it does not reformat.

## Fold them in

```bash
bin/changelog-assemble.sh              # fold every fragment
bin/changelog-assemble.sh --dry-run    # show what would fold
bin/changelog-assemble.sh --check      # exit 1 if any fragment is unfolded
```

The pre-push hook runs the assembler before the guards, so a push never leaves
fragments unfolded. If folding changes the ledger, the push is refused until you
commit the fold — the ledger and the fragments must not disagree.

## The law

This directory is part of the **append-only set** (`RULES/06-append-only.md`).
Fragments are folded in, never dropped; the ledger only ever grows. A move must
carry `CHANGELOG.d/` exactly as it carries `CHANGELOG.md`.

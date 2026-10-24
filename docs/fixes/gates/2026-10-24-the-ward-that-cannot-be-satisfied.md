# The ward that cannot be satisfied — a generated register that is stale the moment it is written

**2026-10-24.** Component: `bin/gates/inventory.sh`, `bin/gates/guards/inventory-guard.sh`.

## What happened

Every push was refused, in the primary checkout and inside a fresh worktree, by one ward: `inventory-guard`, with
the message *"bin/README.md is STALE — run bin/gates/inventory.sh"*. The remedy was followed three times in a row:

1. `bin/gates/inventory.sh` → re-rendered → committed → `--check` **still STALE**.
2. Re-rendered again in another tree → committed → `--check` **still STALE**.
3. Inside an errand worktree, the same, and the push was refused again.

## The proof that it is the generator, not the discipline

Two consecutive renders of the same clean tree differ:

```
$ cp bin/README.md /tmp/before && bin/gates/inventory.sh >/dev/null && diff /tmp/before bin/README.md
15c15
<   "IDEWorkspaceChecks.plist","<xml …>","data","orphan","retire",0,9
>   "IDEWorkspaceChecks.plist","<xml …>","data","wired","keep",0,9
19c19
<   "WhisperCppDemo.xcscheme","<xml …>","data","orphan","retire",0,101
>   "WhisperCppDemo.xcscheme","<xml …>","data","wired","keep",0,101
```

Rows are keyed and sorted by **basename** (`table()` sorts on `r["file"]`, and `analyse()` sets `file=name`), so two
files sharing a basename produce rows that collide in identity and can be written in either classified state. The
verdict itself is a function of `called_by`, which is gathered per name — so for a duplicated name the two files
argue over one row.

## Why this is worse than a normal bug

A gate that can never pass is a gate everybody learns to bypass, and this one blocks **every push** — including the
delivery of four finished errands. It teaches exactly the wrong lesson: *the ward is in the way again*.

## The fix (owed, and it is small)

1. **Key the row by its path**, not its basename: `file` becomes the repo-relative path (`bin/…`, `.agents/backend/…`),
   which is what a register over a tree should say anyway. `sorted()` then has a total order.
2. **Make the verdict a pure function of the tree at HEAD**: gather `called_by` from `git grep` over the tracked tree
   at the commit being rendered, not from a filesystem walk that can see a half-written file.
3. **Add a determinism test to the gate itself**: render twice into two temp files and assert byte equality. A
   generated register that cannot reproduce itself must fail before it can fail anyone else.
4. Until 1–3 land, the ward's message should say *"the generator is not reproducible"* rather than *"run the
   generator"* — the second is advice that cannot work, and today it was given three times to an agent that
   followed it.

## How to see it

```bash
cp bin/README.md /tmp/a && bin/gates/inventory.sh >/dev/null && diff /tmp/a bin/README.md   # differs
bin/gates/inventory.sh --check                                                            # STALE, always
```

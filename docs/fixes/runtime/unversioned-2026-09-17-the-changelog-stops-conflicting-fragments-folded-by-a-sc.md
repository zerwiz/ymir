## runtime · unversioned · 2026-09-17 — the changelog stops conflicting: fragments, folded by a script

### Why
- **The problem, measured.** `CHANGELOG.md` is one file and every branch appends
  at the same position — the top. Git sees two branches inserting different lines
  at the same spot and calls it a conflict, so **every merge re-conflicts every
  open branch**. Sixteen open PRs were each resolved by hand for this reason
  alone, and each merge re-conflicted the rest: O(N²) meaningless conflicts.
- **The fix — `CHANGELOG.d/`.** A change adds **one file with a unique name**
  (`<YYYY-MM-DD>-<slug>.md`) instead of editing the ledger. Two branches never
  touch the same fragment, so the collision cannot occur.
- **`bin/changelog-assemble.sh`** folds fragments into `CHANGELOG.md` — newest
  first, above everything already recorded. Folding is an **append**: existing
  entries are copied verbatim, never reordered, never rewritten. `--dry-run`
  shows what would fold; `--check` exits 1 when fragments are unfolded.
- **The pre-push hook folds first.** `bin/changelog-guard.sh --install` now
  writes a hook that runs the assembler before the guards, so a push never leaves
  fragments unfolded; if folding changes the ledger the push is refused until the
  fold is committed.
- **The guard accepts either form.** A push satisfies the duty by appending to
  `CHANGELOG.md` **or** by adding a fragment. The refusal message now names both.
- **Rule 06 is amended, append-only** — the clause stands; 

### Files
- *(carried from the frozen CHANGELOG.md)*

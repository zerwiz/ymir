## runtime · unversioned · 2026-10-21 — housekeeping asks "is this already in main?"

### What

The worktree audit now asks whether code is already in `main` three ways — tree equality,
patch-id, and a content probe — instead of trusting a commit count. A branch that was
rebased or merged can look "ahead" by count while carrying no unique work; the new test
separates "unique work" from "old shape".

### Verified

- The check is exercised against the local worktree/branch set; it reports the unique
  commits, not merely ahead/behind.
- The commit is cherry-picked onto current `main` for this PR, so it does not revert the
  Snotra evidence files the old branch predates.

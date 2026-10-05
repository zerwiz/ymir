## gate · unversioned · 2026-10-05 — the branch was cut from a stale tree, and the PR would have replaced main's history

### Why

#291 was closed unmerged. It would have merged **976 commits** — 974 *behind* main —
the oldest being PR #6 and PR #7, the beginning of the repository. It would also have
touched `.claude/agents/*`, which the path sweep never touched.

**The cause is the shared tree, and the fault is mine.** This repository is worked on
concurrently: while the sweep was being written, another session moved `HEAD`. When I
ran `git checkout -b`, git cut the branch from whatever `HEAD` happened to be, not from
`main`. The 759-file sweep became two commits on top of an unrelated history.

**Every check had passed.** The gates ran green, the watcher started, the extensions
loaded. **None of them asks whether the branch is rooted on `main` — because that is not
a property of the code.**

### The fix

**Re-cut on a branch whose base is verified.** Before any work:

```
$ git checkout -b <branch> origin/main
$ [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] && echo YES
YES
```

Re-derived on that branch: **4,415 call sites across 640 files**, 292 distinct dead
references, **zero ambiguous** — resolved against the filesystem, never guessed.

Fewer files than before because much of what the first sweep fixed has since been
fixed by other merges. That is the honest measure of what was left, not a smaller job.

### The lesson, and it is the same one as tonight's

> **Nothing in this system fails loudly when the ground moves under it.** A door
> moves and the watcher dies reporting success. `HEAD` moves and a 759-file PR becomes
> an alternative history with a green gate on it.

The PR page read *"wants to merge 976 commits"* and **"1 failing check"**, and the
only visible problem was a conflict. **A commit count is not a code property; it is the
first thing to read on a PR this size.**

### Deliberately not touched

`.agents/backend/fm-*` · `bin/backend/fm-*` · `assets/reference/` — upstream vendored
material naming the upstream shape on purpose. `docs/fixes/**` — Rule 06: a fix note
records a path as it *was*. Fixtures naming absent files exist to be absent.

## runtime · unversioned · 2026-09-17 — the fragment convention is enforced where GitHub runs it

### Why
- **The gap, found by doing it.** The pre-push hook folds fragments before a
  push — but a **GitHub merge bypasses the local hook entirely**. PR #43 merged
  and left its own fragment unfolded on `main`, so the ledger silently fell
  behind what the fragments already told. `bin/changelog-assemble.sh --check`
  catches exactly that state; nothing was calling it.
- **The gate, at the layer that runs.** `.github/workflows/ymir-changelog-fragments.yml`:
  - **on `push` to main** — `bin/changelog-assemble.sh --check` fails when any
    fragment is unfolded, so the ledger can never fall behind a merge.
  - **on a PR** — a change touching code or docs must add a fragment, edit
    `CHANGELOG.md`, or carry the `no-changelog` label. The label records the
    deliberate decision that no entry belongs, rather than letting it be
    forgotten.
- **The pattern is the standard one.** This is the well-trodden "news fragments"
  design (towncrier — Twisted, pytest, pip, attrs; changesets; CPython). The
  zeroc-ice proposal states the root cause exactly: *"PRs edit one shared file.
  Better merge discipline doesn't fix it; not editing the shared file does."*
- **`merge=union` was considered and rejected on evidence.** The Rigor ADR-105
  tried it and measured it: *"GitHub's PR-mergeability and merge computation
  ignore `.gitattributes` merge drivers, union included."* It works against local
 

### Files
- *(carried from the frozen CHANGELOG.md)*

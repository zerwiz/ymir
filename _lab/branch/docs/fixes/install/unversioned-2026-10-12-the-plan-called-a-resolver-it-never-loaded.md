## install · unversioned · 2026-10-12 — The plan called a resolver it never loaded

### Why
- `bin/bridge/ymir-plan.sh` printed `app_pkg: command not found` **three times per run**
  and then **false-passed** phase 5: it emitted
  `CONSENT "build the desktop shells? each pulls a ~100 MB Electron runtime"`
  while all three shells' runtimes were in fact present.
- Cause: `app_pkg` is defined only in `bin/seat/sessrumnir/app-lib.sh`, which the plan
  never sourced. The sibling-lib sweep in `e119ee25` ("the bin move's roots, hoard-lib
  loaders and sibling-lib loaders") seated `bin/desktop/electron-lib.sh` and **missed the
  app-lib sibling**.
- **The naive mend was a trap.** The plan carried its own private `app_dir` with the OLD
  signature — `app_dir <surface> [package]`, printing the path on stdout — while the
  canonical lib has `app_dir <surface> <result-var>`, printing nothing and writing to a
  variable. Sourcing the lib without more would have overwritten the resolver, and every
  call site would have silently received an EMPTY path: a worse lie than the one being fixed.
- Mend: seat the canonical lib at the top of the plan — **before** `app_row` or the shell
  check can run — delete the plan's private copy (Rule 17, no dead code), and move the three
  call sites to the canonical signature. One resolver, not two (Rule 07).

### Files
- `bin/bridge/ymir-plan.sh`

### Verified
- `bash bin/bridge/ymir-plan.sh` — `app_pkg: command not found` is **gone** (was 3 per run).
- Phase 5 against a **built** tree, evaluating the row's own inputs through the canonical
  resolver: `hlidskjalf ok · odrerir ok · sessrumnir ok` → `shells=3` → the row reads
  `SKIP "the three desktop shells' runtimes verify"` (was the false `CONSENT`). The three
  `apps` rows are unchanged (`SKIP — installed, and its build shipped with it`).
- The same fault was measured on **both seats** (heimdall and omarchy) at `646f210b` — the
  code is shared, so the mend is seat-agnostic by construction and belongs in `main`.
- A worktree run reports `DO`/`CONSENT` for the shells, and that is CORRECT: a worktree has
  `apps/` but no builds (`dist/`/`out/` are untracked), so the resolver is telling the truth
  about that tree rather than being broken by it.

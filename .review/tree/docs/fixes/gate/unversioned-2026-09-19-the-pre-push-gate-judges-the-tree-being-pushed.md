## gate · unversioned · 2026-09-19 — the pre-push gate judges the tree being pushed

### Why
- **A push from a Yggdrasil worktree could not pass the gate at all.** The installed
  pre-push hook had the installing tree baked into it at install time
  (`/home/zerwiz/Ymir/bin/...`, `git -C /home/zerwiz/Ymir`). Hooks live in the
  **common** `.git/hooks` and are shared by every worktree, so a worktree push ran
  the main tree's gate against the main tree.
- **And the refusal it printed was not true.** Git exports `GIT_DIR` to hooks, so
  `git -C <main tree> diff --quiet -- CHANGELOG.md` did not read the main tree at
  all: it took the **worktree's** index and compared it against the **main tree's**
  file. The result was a permanent, nonsensical `folded fragments into CHANGELOG.md
  — commit it, then push again` on a clean tree, with nothing folded and nothing to
  commit. `bin/changelog-guard.sh --install` could not even seat the hook from a
  worktree: `$ROOT/.git/hooks` is a path under a **file** in a linked worktree.
- **The gate now judges the tree being pushed**, resolved at hook runtime
  (`git rev-parse --show-toplevel`), and its own git calls are pinned with explicit
  `--git-dir`/`--work-tree` so an exported `GIT_DIR` can never cross trees. No tree
  is baked into the hook; the hook is the same bytes in every worktree.
- **`--install` seats the hook in the common git dir** (`git rev-parse
  --git-common-dir`), which is where git reads it and where every worktree shares
  it — so the gate can be installed from any tree.
- **Same family, not yet mended:** `bin/secret-guard.sh --install` (`$ROOT/.git/hooks/pre-commit`)
  and `step_gates` in `bin/ymir-install.sh` still name `$ROOT/.git/hooks` directly,
  so they are worktree-fragile in the same way. Recorded here rather than silently
  widened in this change.

### Files
- `bin/changelog-guard.sh` — the hook template and `--install`

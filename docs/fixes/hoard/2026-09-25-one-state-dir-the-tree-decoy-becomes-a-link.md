## hoard · unversioned · 2026-09-25 — one state dir: the tree decoy becomes a link

### Why
Plan 58's Phase 0: runtime state belongs to the operator's home
(`$YMIR_HOME/state`), resolved through `bin/hoard-lib.sh` (Rule 04). The code
tree kept a **second** `state/`; a reader that resolved the tree saw a dead
session and stood down — on 2026-09-25 a **live** arm read as dead because
`state/.lock` held a dead pid while the hoard's lock was fresh. #203 made four
writers resolve-or-refuse, but the decoy remained and every script whose
`BROKK_HOME` is unset still fell back to `$ROOT/state`.

- **The tree keeps the NAME, drops the DIRECTORY.** Migration
  `0007-one-state-dir` moves any entry into the home's state (duplicates into
  `.recovered-tree-state/`, nothing deleted) and replaces `$ROOT/state` with a
  **symlink** to `$YMIR_HOME/state`. Every `$ROOT/state/...` fallback now lands
  in the one truth — no per-script edits to drift. `.gitignore` ignores `state`
  outright; the tracked `state/.gitkeep` is retired, because a link needs none.
- **Every extension reader resolves the home, not the tree.** Added
  `resolveYmirHome()` to `.pi/extensions/lib/ymir-home.ts` (env → recorded home →
  documented default) and used it in `syn-turnend-guard.ts`,
  `skuld-branch-supervision.ts`, `ro.ts`, `open-editor.ts`, and `gna-pi-watch.ts`
  (deduped). `skuld` was the odd reader: it read `${state}/.lock` directly and so
  never saw a primary's machine-global lock — it now resolves `state/.lock-path`
  like its siblings.
- **The purity ward learns the cure.** `bin/ymir-plan.sh`'s `purity` row treats a
  `state` **symlink** as clean, and flags only a real directory with entries.
- **Proved live:** `state -> /home/heimdall/Documents/ymirhome/state`; a write
  through `$ROOT/state/.probe` lands in the hoard; `resolveYmirHome()` answers
  `/home/heimdall/Documents/ymirhome`.

galdr-reread: `harness-integration/README.md` (the tree `state/` link and
`resolveYmirHome`).

### Files
- `.agents/migrations/0007-one-state-dir.sh`
- `.gitignore`
- `bin/ymir-plan.sh`
- `.pi/extensions/lib/ymir-home.ts`
- `.pi/shared/extensions/{gna-pi-watch,syn-turnend-guard,skuld-branch-supervision,ro,open-editor}.ts`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`

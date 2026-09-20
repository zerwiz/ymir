## runtime · unversioned · 2026-09-16 — four readers that still pointed at the pre-split world

### Why
The app split and the hoard migration moved things; four readers never followed.
None failed loudly — each reported a clean PASS, a wrong SKIP, or a silent loss.

- **`bin/ymir-install.sh` wrote during `--check`.** The step chain ran
  `bin/ymir-migrate.sh apply` unconditionally, so a preview that promises *"report
  only, no writes"* actually **moved private data**. Migrations now apply only on
  a real run: `if [ "$CHECK" = 0 ]; then ... apply; fi`.
- **`.agents/migrations/0003-private-data-separation.sh` skipped every directory.**
  It pre-creates its target dirs, then its `copy` refused any target that already
  existed — so `data/` (and every other directory source) was silently dropped.
  The realm declaration never arrived and `0004` fell back to a neutral realm.
  `copy` now **merges** a directory into its target (never overwriting a file) and
  copies a single file only when it is absent.
- **`bin/smidja-bootstrap.sh` looked for the smithy at the old root.** `sys.path`
  pointed at `smidja/`, but the split moved it to `apps/smidja/`, so the DB seed
  died with `ModuleNotFoundError: No module named 'smidja_modules'`. It now
  searches `apps/smidja` then `smidja`, so either layout works.
- **`bin/ymir-validate.sh` read the ledger from the pre-move path.** It looked at
  `$YMIR_HOME/memory/`, but `0004-hoard-and-realms` put the ledger at
  `$YMIR_HOME/hodd/memory/` — a fa

### Files
- *(carried from the frozen CHANGELOG.md)*

## gate · unversioned · 2026-10-12 — the inventory counted the seat, not the tree — its --check was a lottery

### Why
inventory.sh's header promises 'the corpus is now git ls-files: TRACKED files only ... or its --check is a lottery', but the shelf walk still used d.rglob('*'), so untracked live state under bin/state/ (cron.log, .session-start-complete) was analysed and its called-by/verdict counts moved as the machine ran. Two writes of the same tree differ; a locally-generated register cannot match a clean checkout, so --check failed on CI for a difference no diff shows. Fix: the shelf walk now filters to the tracked set, exactly as the header says. Two writes are byte-identical and --check is green. The stray worktree nested at bin/.yggdrasil/ (2,973 files, 87% of bin/) was retired to ~/ymir-worktree-quarantine/ by 'git worktree move' — it also made this generator quadratic and polluted every bin/-walking ward.

### Files
- `bin/gates/inventory.sh`
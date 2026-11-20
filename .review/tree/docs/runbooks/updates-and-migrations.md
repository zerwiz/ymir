# Runbook — updating the runtime and healing old homes

## Update the code

```bash
bin/brokk-update.sh          # fast-forward this home + every registered Eindri-home
```
It never forces or stashes; it reports one row per target. After updating, run
the structure migrations below.

## Structure migrations (old homes heal forward)

Versioned, idempotent scripts in `.agents/migrations/` transform an older home
into the current layout (e.g. `0001-ymir-home` moves private material into
`$YMIR_HOME`).

```bash
bin/ymir-migrate.sh status            # what exists / what is applied
bin/ymir-migrate.sh apply --dry-run   # show what would run
bin/ymir-migrate.sh apply             # apply pending, in order
```
Applied ids are recorded in `state/migrations` (private). Each migration must be
idempotent — re-running is safe. `bin/ymir-install.sh` and `bin/brokk-update.sh`
call `apply` after an update.

## Add a migration

1. Create `.agents/migrations/NNNN-<name>.sh` (next number), idempotent.
2. It runs with `bash` from the repo; move/transform, print what it did.
3. Test: `bin/ymir-migrate.sh apply --dry-run`, then `apply`.

## First-time setup

```bash
bin/ymir-install.sh            # full setup (idempotent)
bin/ymir-install.sh --check    # all steps OK/WARN
```

## Re-cloning a home whose history has diverged

If `git push` from a home is rejected with "unrelated histories" — or
`git merge-base HEAD origin/main` prints nothing — the working copy and the
remote no longer share an ancestor. The home cannot be pushed. Clone fresh and
move into it; do not try to reconcile the histories.

**What a clone does NOT carry.** Plan for all of it before you switch:

| Missing from a clone | Why it matters |
|---|---|
| `.env.local`, `state/`, `data/` | secrets and runtime state — the home cannot boot without them |
| the realm tree, `workspace/` | the operator's private world (untracked by design) |
| `YMIR_HOME` | the private hoard — committed to the private git repo, shareable |
| local-only branches | **anything never pushed exists only here.** Check with `git branch` and compare against `git branch -r` |
| `.yggdrasil/` worktrees | each is registered by **absolute path** to this home's `.git` |
| `node_modules` | rebuildable — see `installation.md` for the postinstall trap |

**Procedure**

```bash
# 1. Secure first. Everything below is cheap; the mistake is not.
git bundle create /backup/branches.bundle $(git branch --format='%(refname:short)' | grep -v '^main$')
git bundle create /backup/history.bundle --all
tar czf /backup/essentials.tgz state .env.local data workspace svartalfaheim hodd
tar czf /backup/yggdrasil.tgz .yggdrasil
git diff > /backup/uncommitted.patch
for w in .yggdrasil/*/; do git -C "$w" diff HEAD > "/backup/wt-$(basename $w).diff"; done

# 2. Clone current, and prove the clone is behind-nothing before you move in.
git clone <remote> ~/ymir-new && cd ~/ymir-new && git log --oneline -1

# 3. Import the local-only branches, then carry the private paths across.
git fetch /backup/branches.bundle 'refs/heads/*:refs/heads/*'
cp -a ~/ymir/.env.local . && for d in state data svartalfaheim workspace; do cp -a ~/ymir/$d/. $d/; done
cp -a ~/ymir/hodd . 2>/dev/null || true

# 4. Swap, keeping the old home for rollback.
mv ~/ymir ~/ymir-old && mv ~/ymir-new ~/ymir

# 5. Re-create the worktrees from the imported branches, then restore their working state.
git worktree prune
for b in $(git branch --format='%(refname:short)' | grep '^yggdrasil/'); do
  git worktree add ".yggdrasil/${b#yggdrasil/}" "$b"
done

# 6. Heal forward and verify.
bin/ymir-migrate.sh status && bin/ymir-migrate.sh apply
bin/ymir-install.sh --check
```

**Traps this procedure was learned from**

- **Carrying private paths over a fresh clone can clobber newer tracked files.**
  `cp -a workspace/.` overwrote a `workspace/README.md` that the remote had
  evolved past. Carry the *untracked* private trees (`state`, `data`, `hodd`,
  `.env.local`) and copy realm/workspace content only after checking
  `git status` — then restore any tracked file the carry dirtied:
  `git checkout -- <path>`.
- **`tar` copies files, not absences.** A worktree with *staged deletions* comes
  back with those files present again. Compare each restored worktree against its
  pre-swap `git status --porcelain` record and replay the deletions
  (`git rm -f <path>`), or apply the saved `git diff HEAD` patch.
- **Worktree registrations are absolute.** Rename the home and every worktree
  loses its `gitdir`, so `git` fails inside it until `git worktree prune` +
  `git worktree add` rebuild the registration. The `.git` never has to move —
  but if you move the home, expect to rebuild them.
- **Verify the restore, do not assume it.** For each worktree, diff its current
  `git status --porcelain` against the record taken before the swap. Everything
  matching is the acceptance test.

Rollback at any point: `mv ~/ymir ~/ymir-failed && mv ~/ymir-old ~/ymir`.

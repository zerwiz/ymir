## gate · unversioned · 2026-10-18 — branch-guard judges the destination, not the branch you stand on

### Why

`bin/gates/guards/branch-guard.sh` read the pushed refs from stdin — and, before
the loop, **also judged the branch the operator was standing on**:

```bash
current="$(git symbolic-ref --short HEAD …)"
is_protected "$current" && block "$current"
```

So with `HEAD = main`, **every** push was refused as *"a direct push to 'main'"* —
including `git push origin --delete <a-merged-feature-branch>`, which lands on
nothing of the sort. Deleting a merged branch from `main` required `--no-verify`.
The loop below already checks the destination ref correctly; the pre-check was
redundant and harmful.

Found in the act: cleaning up after PR #349 (`git push origin --delete
docs/security-the-ward` from `main` → *Rule 08 violation: direct push to 'main'*).
The house's own doctrine applies — *a gate that must be routinely overridden is a
gate nobody trusts* (the same sentence that fixed the fixes-guard matcher on
2026-10-01).

### Now

The guard judges **the refs the push names**, and nothing else. Standing on `main`
while pushing — or deleting — a *feature* branch is legal; landing on `main` is
still blocked, and **deleting** a protected branch is blocked too. When run by
hand with no refs on stdin, it falls back to judging the current branch, which is
what a bare `git push` would land on.

### Verified

`.agents/tests/branch-guard-delivery.test.sh` → **7 passed, 0 failed**: a feature
branch may be pushed while HEAD is `main` (the bug); a push landing on `main` is
blocked; deleting a merged feature branch is allowed; deleting `main` is blocked;
a manual run with no refs judges the current branch; `--branch main` is blocked and
`--branch my-feature` allowed. No test covered this guard before.

### Files

- `bin/gates/guards/branch-guard.sh`
- `.agents/tests/branch-guard-delivery.test.sh` (new)
- `bin/README.md`, `.agents/assets/agents/capabilities.md` (regenerated)

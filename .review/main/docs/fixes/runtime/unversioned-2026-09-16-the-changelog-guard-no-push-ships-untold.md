## runtime · unversioned · 2026-09-16 — the changelog guard: no push ships untold

### Why
- **Every push carries a CHANGELOG entry.** `bin/changelog-guard.sh` installs a
  pre-push hook that reads the refs git hands it, resolves the range being
  pushed, and refuses the push when `CHANGELOG.md` is untouched in that range.
  A change that ships is a change that was told; the record can no longer lag
  silently behind the code.
- **Rule 08 extracted and versioned.** The protected-branch check that lived
  only inside the ad-hoc `.git/hooks/pre-push` is now `bin/branch-guard.sh`, so
  the delivery gate is reproducible: `bin/changelog-guard.sh --install` writes
  the pre-push that runs both guards.
- **Escape hatch, deliberate and loud.** `YMIR_SKIP_CHANGELOG_GUARD=1 git push`
  when an entry truly does not belong.
- Checks by hand: `bin/changelog-guard.sh --range A..B`,
  `bin/branch-guard.sh --branch main`.

### Files
- *(carried from the frozen CHANGELOG.md)*

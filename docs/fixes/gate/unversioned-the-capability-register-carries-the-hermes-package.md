## gate · unversioned · 2026-11-18 — the capability register carries the new hermes package

### Why
CI run 44337627997 failed its `capability` gate on PR 819: the new `src/ymir_runtime/hermes/` package was not in the generated register, and the `doors` row read `no` where the tree says `yes`.

### Files
- `.agents/assets/agents/capabilities.md`
- `docs/fixes/gate/unversioned-the-capability-register-carries-the-hermes-package.md`

### What
Re-wove the register with `bin/gates/capabilities.sh`; it added seven `hermes` module rows and corrected the `doors` row.

### Verified
`bin/gates/capabilities.sh` wrote the register (34 fragments, 42 folder rows); the diff is those rows only. The gate itself is re-run by CI on this push.

## CHANGE LOG

- **2026-11-18** — opened.

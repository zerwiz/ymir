## gate · unversioned · 2026-10-11 — vault-guard: it never ran, and nothing re-seated it

### What

Two real defects in the ward delivered by Rule 15 (PR #313), found the moment it was
exercised on `main`:

1. **It printed help instead of scanning.** `vault-guard.sh` matched `""` in its
   *help* case, so invoked **with no arguments** — exactly how a **pre-commit hook**
   calls it — it printed usage and exited 0. The guard existed and never checked.
   Fixed: no args now scans the staged change (the pre-commit path).
2. **Nothing re-seated it.** The repo's pre-commit hook is *generated* by
   `secret-guard.sh --install`, and the home's by `hoard-guard.sh --install`. Neither
   knew about `vault-guard`, so the next install would silently drop it. Fixed: both
   installers now write a `vault-guard` line (guarded by `[ -x … ]`, so an older tree
   that lacks the script skips cleanly instead of blocking every commit).

The proof now covers the no-args case, so a guard that prints help on no args can
never pass again.

### Verified

- `tests/e2e/vault-guard-proof.sh` — **all pass**, including *"no-args (pre-commit)
  scans the staged change"*.
- `bash -n` clean on all three scripts; the generated hook line contains
  `vault-guard.sh`.

### Files

- `bin/gates/guards/vault-guard.sh`
- `bin/gates/guards/secret-guard.sh`
- `bin/gates/guards/hoard-guard.sh`
- `tests/e2e/vault-guard-proof.sh`

# the well door reconciled with the arm's seat sweep, and the gates made green

**Date:** 2026-11-10 · **Component:** gate (branches: `eindri/well-door-harness`)

## What was wrong

- Another hand merged `main` into `eindri/well-door-harness` (commit `9752a73f`) and resolved
  the shared files in main's favour, dropping this PR's second half: Eir's `claudehooks`
  surface, the `harness-extensions` rows in `ymir-install.sh`, and the two asset sections.
- The CI `mocks-vocabulary` gate saw a half-built door: `bin/bridge/mcp-config-seat.py` named a
  local variable `todo`. It also saw the #639 seat-reap fixture's `$T/stub` path, the only
  inherited mocks hit on `main`.
- The `inventory` gate was stale on this branch, and on `origin/main` too: fourteen `INDEX.md`
  files and `.agents/backend/README.md` had not been regenerated after #639 added files.

## Fix

- Restored this PR's second-half edits onto `9752a73f` (no force-push, no dropped hand): Eir's
  `claudehooks` surface, `step_loaders`' harness-extensions rows in both `--check` and install,
  the harness-integration and installation asset sections, and the capability fragments.
- Renamed `todo` → `pending` in `mcp-config-seat.py`; renamed the #639 fixture path
  `$T/stub` → `$T/fixtures` (the variable name `STUB_DIR` is unchanged, and the word is
  already excused in comments).
- Regenerated `bin/` inventory and capabilities; `inventory --check` and `registers --check`
  are current.

## Proof

- `bash .agents/tests/mocks-scan.test.sh` → all four rows ok, including "the shipped tree
  passes its own scan".
- `bash bin/gates/inventory.sh --check` → `current — 35 index file(s), 912 bin doors`.
- `bash bin/gates/registers.sh check` → both generators `current`.
- `bash bin/gates/tests/test_arm_client_helm.sh` → 5/5 PASS.
- `bin/seat/harness-extensions-install.sh` in a throwaway `HOME`: the three Claude hooks
  `current`, one entry each, the operator's own hook and `permissions` preserved.
- `python3 bin/mcp/ymir-mcp.py --selftest` → `doors: 47`.

## Inherited from main (named, not mended here)

`defaults-guard`, `public-data-guard`, `features-guard`, `weave-guard`,
`rules-compliance-guard` and `pr-identity-guard` are red on `origin/main`; the pre-push guard
names them as main's, not this branch's. `config` still trips on `test_broken.sh`,
`test_finding_tally.sh` and `test_pr_identity.sh` paths.

# REPORT — the well door for every harness, and its gate follow-up

**PR #640 (the feature):** https://github.com/zerwiz/ymir/pull/640 — **MERGED** `04ff3ca9` (2026-11-11T00:38Z).
**PR #652 (the gate greens):** https://github.com/zerwiz/ymir/pull/652 — open, head `b308176a`,
based directly on `origin/main@fcee1bb8` (1 commit, 0 behind).

## What happened

The feature PR merged while the reconcile was in flight. `#640` landed at its pre-reconcile state:
its CI `gates` job was red and its `bin/` inventory was stale, and it carried the mocks-scan word
`todo`. The reconcile could not be pushed to the merged branch (a plain push was rejected: the branch
had diverged from the remote, and rewriting the foreign merge `9752a73f` was forbidden). So the
gate-green work was landed as a fresh, current branch off `origin/main`: **#652**.

## #652 — per-file

- `bin/bridge/mcp-config-seat.py` — local `todo` → `pending` (mocks-vocabulary).
- `bin/seat/tests/test_seat_reap.sh` — fixture path `$T/stub` → `$T/fixtures` (the only other mocks
  hit; inherited from #639/main).
- `bin/gates/tests/test_arm_client_helm.sh` — inline comment "stub" → "child".
- `bin/INDEX.md`, `bin/*/INDEX.md`, `.agents/backend/README.md`, `.agents/assets/agents/capabilities/*`,
  `FEATURES.md` — regenerated (main was stale on fourteen indexes and the backend README).
- `docs/fixes/gate/2026-11-10-the-well-door-reconcile.md` — the fix note.

## Verified on #652's tip

- `bash .agents/tests/mocks-scan.test.sh` → 4/4 ok, including "the shipped tree passes its own scan".
- `bash bin/gates/inventory.sh --check` → `current — 35 index file(s), 913 bin doors`.
- `bash bin/gates/registers.sh check` → both generators `current`.
- Pre-push wards: `branch-current` current (0 behind, 1 ahead); `fixes-guard` ok with 1 note.

## Inherited from main — named, not mended

`defaults-guard`, `public-data-guard`, `features-guard`, `weave-guard`,
`rules-compliance-guard`, `pr-identity-guard` (red on `origin/main`); `config` trips on
`test_broken.sh`, `test_finding_tally.sh`, `test_pr_identity.sh`.

## Overlap with PR #639 (named as asked)

#639 touched `bin/pi/syn-watch-arm.sh`, `bin/agents/eir-doctor.sh`, `bin/engine/ymir-install.sh` and
`bin/agents/einherjar-spawn.sh` (not `harness-extensions-install.sh`, contrary to the note). #640's
merge reconciled them and kept both halves: Eir's `seats` and `claudehooks` surfaces, the install
`seats` and `harness-extensions` rows, #639's arm-road sweep, and #640's helm gate + client
retirement. The two lands in either order without loss. #652 adds only the one-token fixture rename in
#639's test.

## Arm faults (verified in #640, still true)

`bin/gates/tests/test_arm_client_helm.sh` → 5/5 PASS: a stranger helm is refused read-only and writes
no pidfile; a held helm retires the two older stubbed clients and records the new one.

## Final outcome — both PRs merged (2026-11-11)

- **#640** (the feature) squash-merged as `04ff3ca9` at its OLD head `9752a73f`; the reconcile
  commit `ee2982f9` was dropped by the squash. That is exactly plan 243's "squash drops follow-up
  commits" and it is why main stayed red and a follow-up was needed.
- **#652** (the gate greens) merged as `3f263f69`. Main now carries `pending`, `$T/fixtures`, the
  reworded arm-test comment, the regenerated inventory and the fix note. Verified on `origin/main`.
- A foreign hand added `6a72af5a` (merge main into the gate branch) before the squash; the tree
  landed intact.
- Plan 243 is in force now: generated files are no longer hand-resolved; I take main's copy and
  regenerate once; migration/plan numbers only from origin/main; a multi-commit branch merges,
  never squashes. This branch is finished and quiet.

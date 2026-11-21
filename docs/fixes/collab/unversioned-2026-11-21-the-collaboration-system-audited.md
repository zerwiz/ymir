## collab · unversioned · 2026-11-21 — the collaboration system audited

### Why

The operator asked how much of the open collaboration plans (335, 343, 345, 346 and the company-server plan 0003) can
become code, and whether the code base should be upgraded to carry them.

### What changed

- **`docs/audits/2026-11-21-the-collaboration-system.md`** (new): every piece of the collaboration system, its tests
  (run), its health, each open plan step classified as code, configuration, decision or already built, the upgrade, and
  the first three slices.

No code changed. The tests were only run.

### Found, and not fixed here

- `.agents/tests/gather.test.sh` is red on `main` (18 failed): its fixture does not copy `bin/forge/warden-lib.sh`, which
  `gather.sh` now sources.
- `bin/gates/tests/test_card_door.sh` is red: the GitHub carry case.
- `bin/collab/letter.sh:24` gives a real company name as the default sender (RULES/04).

Both red tests are named as part of the third slice in the audit.

### Files

- `docs/audits/2026-11-21-the-collaboration-system.md`
- `docs/fixes/collab/unversioned-2026-11-21-the-collaboration-system-audited.md`

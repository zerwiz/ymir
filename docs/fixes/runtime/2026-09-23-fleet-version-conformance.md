## runtime · unversioned · 2026-09-23 — fleet version conformance (plan 51 Phase 2)

### Why
- **Problem:** the fleet had three different versions with no alarm — tree
  `0.1.39`, npm `latest` `0.1.50`, installed `0.1.45`. Law 5 says the fleet is
  versioned together; nothing read the three and judged them.
- **Fix:** `bin/fleet-version.sh` reports the **tree** (repo `package.json`), the
  **installed** (`@zerwiz/ymir` in the global prefix), and the **published**
  (`npm view`, network-optional), and gives a **verdict**:
  `in sync · drift · ahead · behind · unknown`, with semver-ish comparison
  (`sort -V`). `--json` for machines; `check` exits 1 on `drift`; an unreachable
  registry reports `unreachable`, never a crash.
- **Also:** the smoke test gains a `version` check (in sync/ahead → OK;
  drift/behind → SKIP with the detail, so the gate flags the drift without
  blocking on the Allfather's release decision).

### Verified
- `.agents/tests/fleet-version.test.sh` — **ALL PASS**: matching tree is not
  drift; a differing tree is drift and `check` exits 1; JSON parses; a missing
  `package.json` degrades to `unknown`.
- On this box it names the real drift: `tree 0.1.39 != installed 0.1.45`
  (published `0.1.50`).

### Files
- `bin/fleet-version.sh`
- `.agents/tests/fleet-version.test.sh`
- `.agents/skills/lifecycle/smoke_test.sh`

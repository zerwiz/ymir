## runtime · unversioned · 2026-09-12 — The well actually installs (it never did)

### Why
- **The memory engine was never installed by the installer.** `bin/prereq-ensure.sh`
  had no `engram` target at all, and `bin/ymir-install.sh` only *checked* for it
  and printed `SKIP "optional — install engine then run bin/mimir-bridge.sh"`. A
  SKIP never blocks, so the well was silently down on every install.
- **The hint named the wrong package.** PyPI's `engram` is an unrelated
  *rendering* library (mitsuba/drjit/torch): following the hint pulled gigabytes
  of CUDA wheels and still left no engine. The memory engine's distribution is
  **`engdbram`**; its module is `engram`. The pre-swap append-only log had the
  right answer all along (`PyPI engdbram, v2.2.1`).
- **Now it installs.** `prereq-ensure.sh engram` installs `engdbram` into an
  interpreter that can run it (>=3.11; uv supplies 3.12 here), records that
  interpreter in `~/.config/ymir/engram-python`, and `bin/mimir-bridge.sh` reuses
  it for both the check and the run. The installer provisions rather than hints,
  and reports WARN instead of a silent SKIP when it cannot.
- **Verified:** `curl 127.0.0.1:4602/health` -> `{"status": "up", "store":
  ".agents/memory/kaia.engram"}`; `.agents/skills/lifecycle/smoke_test.sh` exits 0
  with all five checks green.

### Files
- *(carried from the frozen CHANGELOG.md)*

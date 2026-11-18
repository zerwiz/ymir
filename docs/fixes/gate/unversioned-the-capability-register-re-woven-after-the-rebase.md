## gate · unversioned · 2026-11-18 — the capability register re-woven after the rebase onto main

### Why
CI run 44347336277 on PR 819 failed its `capability` gate again. The rebase onto main (which held PR 818) kept main's copy of the generated register, so the new `hermes` package rows and the `doors` row were missing a second time.

### Files
- `.agents/assets/agents/capabilities.md`
- `.agents/assets/agents/capabilities/seat.md`
- `docs/fixes/gate/unversioned-the-capability-register-re-woven-after-the-rebase.md`

### What
Re-ran `bin/gates/capabilities.sh` on the rebased tree; the diff is the generated rows only.

### Verified
The generator wrote the register and the diff is the 15 added and 3 changed generated lines. CI re-derives it on this push.

## CHANGE LOG

- **2026-11-18** — opened.

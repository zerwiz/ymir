## agents · unversioned · 2026-09-20 — RÖDD speaks again: the injector was the last straggler to walk its own path

### Why
- **No RÖDD operational input was injected at all** — not session-start, not
  watcher, not turn-end-guard, not branch-outcome. The four Pi extensions were
  mended (2026-09-19) to resolve the distro root from the deploy-time record
  (`resolveYmirRoot` + `.ymir-root`), but `rodd-operational-input.ts` — the shared
  **lib** module those four import for encoding — still walked its own
  `../../../bin/rodd-operational-input.sh`. Deployed to `${HOME}/.pi/agent/extensions/lib/`,
  that resolves `${HOME}/.pi/bin/rodd-operational-input.sh`, which does not exist:
  `spawnSync` failed, `encode` threw, the frame never left.
- **The same wound killed the arm.** The globally deployed extensions were stale
  (Sep 17) — before the root-record contract — so `bin/syn-watch-arm.sh` was exec'd
  from a path that did not exist; the Gná arm child died 127 before its first poll
  and no heartbeat was written for days.
- **Fixed:** the injector now resolves through `resolveYmirRoot` like its four
  siblings (relative + recorded, no hardcoded path — Rule 07); `bin/valknut-load.sh --pi`
  re-run so `.ymir-root` → `/home/zerwizomar/ymir` is recorded, `ymir-home.ts` shipped,
  and the six deployed files current. Verified: the deployed helper resolves the root;
  `bin/rodd-operational-input.sh encode session-start` emits a real frame.
  A new session carries the fix — a running one holds the code it loaded.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` —
the straggler named, beside the Sep 19 root-record mend.

### Files
- `../../../bin/rodd-operational-input.sh`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
- `bin/syn-watch-arm.sh`
- `rodd-operational-input.ts`
- `ymir-home.ts`

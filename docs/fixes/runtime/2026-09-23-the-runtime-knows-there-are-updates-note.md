## runtime · unversioned · 2026-09-23 — the UPDATE section in the digest's asset

### Why
The change that added an `== UPDATE ==` section to `bin/saga-session-start.sh`
left its governed asset behind, and compliance caught it: *"stale (asset not
updated): saga-session-start.sh"*.

### Fix
- **`.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`** — the
  emitted-headers list gains `== UPDATE ==`, and the stage table gains its row
  (4b): the source is `bin/ymir-update-check.sh`, one cached lookup a day, silent
  with no network, **exit 3** when a newer version stands.

### Verification
- Compliance gate: **15/15 PASS** (the `assets` check is the one this satisfies).

### Files
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`

## runtime · unversioned · 2026-09-23 — the digest's paths, named truly in the asset

### Why
The `brokk-distro-runtime.md` asset documented the CONTEXT DIGEST's source as
plain `data/`. That is exactly the ambiguity that produced the bug fixed in the
same branch: the digest read `$BROKK_HOME/data` — the **code tree** — and printed
`operator: ABSENT, projects: ABSENT, learnings: ABSENT` every session while the
records sat in `$YMIR_HOME/hodd/data/`.

### Fix
- **`.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`** — the row
  now names the real source: `$YMIR_HOME/hodd/data/` via `bin/hoard-lib.sh`
  (`BROKK_DATA_OVERRIDE` wins), never `$BROKK_HOME/data`.

### Verification
- Compliance gate: 15/15 PASS (the `assets` check is the one this satisfies).
- The documented path and the code agree.

### Files
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`

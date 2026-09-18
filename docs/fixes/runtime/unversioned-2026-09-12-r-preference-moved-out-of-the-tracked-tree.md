## runtime · unversioned · 2026-09-12 — Ró preference moved out of the tracked tree

### Why
- `.agents/config/ro` was a **git-tracked** per-user toggle (calm on/off); any
  toggle dirtied the tree and made `bin/brokk-update.sh` refuse. It now lives in
  the gitignored `state/ro`; `YMIR_RO`/`BROKK_RO` set a default; the legacy
  `config/ro` is read once for upgrade then never written. Tracked file removed.

### Files
- *(carried from the frozen CHANGELOG.md)*

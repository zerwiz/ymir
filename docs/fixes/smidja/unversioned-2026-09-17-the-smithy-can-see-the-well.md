## smidja · unversioned · 2026-09-17 — the smithy can see the well

### Why
- **Why the memory looked absent in the smithy:** the visualizer proxies the bridge's
  `/inspect`, and `/inspect` reported three fields — store, episodes, agents — while
  the well holds six layers. A panel told only the episode count cannot show that
  facts, entities and reflections exist. `/inspect` now reports them all:
  episodes, facts (active/superseded), entities, edges, reflections (with the last
  run's time) and the vector index.
- **Through the smithy right now:**
  `store $YMIR_HOME/memory/kaia.engram · episodes 8 · facts 36 (35 active) ·
  entities 60 · edges 480 · reflections 1 (2026-09-16T21:01) · vec index 8`.
- **A trap found while doing it:** restarting the bridge RAW (`python3 bin/mimir-bridge.py`)
  loses the env that carries the well's path, and the bridge silently re-points at the
  old store in the repo — 364 stale episodes and no facts. The well is the **blessed
  starter's** to raise: `bin/mimir-bridge.sh --start`. A raw restart is a different
  well wearing the same port.

### Files
- *(carried from the frozen CHANGELOG.md)*

## agents · unversioned · 2026-10-12 — the well syncs by the log, not by merging the engram

### Why
The fleet's wells forked: the heart published its engram and no seat ever pulled it, while every seat's bridge wrote its own local engram. Three breaks, all found in the design record (34c598a, 2026-09-21: 'every machine pulls the one memory and pushes its own' — but only the push was scheduled; the pull was assumed to 'live on each far machine' and was never wired; then 5bafc2a, 2026-09-24, gated the line @heart, so a dev body ran none). Fix: the append log (hodd/memory/well/episodes.jsonl) is the unioned TRUTH and the engram is a derived, per-seat index. The bridge now appends EVERY observe to the log (the one door all harnesses pass through; previously only mimir.sh/mimir-ingest.sh did, so the log held 5 lines against 101 episodes). New bin/records/mimir-log.{py,sh}: export (engram->log), union (append-only), reseed (log->engram), verify (the gap). bin/time/well-vault-sync.sh now syncs the log, unions with origin, and reseeds the index — never git-merging the binary engram. The interpreter resolver moves to one place (bin/bridge/mimir-bridge.sh --python). A seat keeps the whole memory even with the heart down, and publishes its own when it returns; the heart is the main port, not a single point of failure.

### Files
- `bin/bridge/mimir-bridge.py`
- `bin/bridge/mimir-bridge.sh`
- `bin/records/mimir-log.py`
- `bin/records/mimir-log.sh`
- `bin/time/well-vault-sync.sh`
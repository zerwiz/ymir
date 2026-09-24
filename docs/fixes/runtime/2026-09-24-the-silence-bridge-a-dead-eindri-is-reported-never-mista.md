## runtime · 2026-09-24 · 2026-09-24 — the silence bridge — a dead Eindri is reported, never mistaken for a thinking one

### Why
The delivery seam (state/<id>.status to the wake lib) produced no heartbeat at all for a worker that died before appending anything, and nothing ever checked a live worker's last-append age. Now every spawn records launched= and appends a heartbeat baseline; bin/eindri-heartbeat.sh treats no append inside a configurable window as SUSPECT (silent|fresh|terminal|absent); bin/eindri-acclaim-silent.sh wakes Brokk idempotently with id, elapsed time, and last line; eindri-watch arm and arm-silence seat the pair.

### Files
- `bin/eindri-heartbeat.sh`
- `bin/eindri-acclaim-silent.sh`
- `bin/eindri-watch.sh`
- `bin/einherjar-spawn.sh`
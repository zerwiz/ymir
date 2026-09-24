## runtime · unversioned · 2026-09-24 — the silence bridge — a dead Eindri is reported, never mistaken for a thinking one

### Why
The delivery seam (state/<id>.status → wake lib) existed but produced no heartbeat at all for a worker that died before appending anything, and nothing ever checked a live worker's last-append age. A dead worker looked exactly like a busy one. Now every spawn records launched= + launch_iso= in the meta and appends a heartbeat baseline to the status; bin/eindri-heartbeat.sh treats no append inside a configurable window as SUSPECT (silent|fresh|terminal|absent), bin/eindri-acclaim-silent.sh wakes Brokk idempotently with the worker's id, elapsed time, and last line, and bin/eindri-watch.sh arm/arm-silence seats the pair so a dead smith rings, once, instead of silently idling beside the work.

### Files
- `bin/eindri-heartbeat.sh`
- `bin/eindri-acclaim-silent.sh`
- `bin/eindri-watch.sh`
- `bin/einherjar-spawn.sh`
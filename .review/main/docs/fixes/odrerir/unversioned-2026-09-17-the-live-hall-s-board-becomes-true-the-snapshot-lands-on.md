## odrerir · unversioned · 2026-09-17 — the Live Hall's board becomes true: the snapshot lands on the loom

### Why
- **The Hall was a glass with nothing behind it.** The Óðrerir page reads
  `apps/odrerir/public/livehall.json` same-origin, but nothing wrote it on a
  schedule — the board showed the saga's own static count and said so.
  `bin/nornir-job-hall-snapshot.sh` (08:00, after the 06:00 observer and the
  07:00 briefing) now drives `bin/hall-snapshot.sh` from real state — runes,
  projects, the cron gauge, the wake queue, standing smiths, armed when-
  sources, landed errands — and carves Rune `odrerir / hall.snapshot`.
- The snapshot is runtime, never repo: `apps/odrerir/public/livehall.json` is
  gitignored, so the job never dirties a branch.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md` — new
§3.5 row (reads/writes table, idempotence note).

### Files
- *(carried from the frozen CHANGELOG.md)*

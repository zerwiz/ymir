## hlidskjalf · unversioned · 2026-09-17 — the NorthStar gate runs nightly; the platform door it caught is mended

### Why
- **`bin/nornir-job-nsr-compliance.sh` (02:30)** runs every
  `.compliance/gates/check_*.sh` (danger · env · paths · platform · wiring)
  and carves the verdict — `nsr.compliance` clean, or `nsr.compliance.failed`
  (exit 1) naming the broken gate, so the 07:00 briefing reads it at sunrise.
- **The gate it caught, mended:** `scripts/electron.sh` used `kill -9`, which
  the platform gate rightly refuses as non-portable. It now uses `kill -KILL`
  (the house idiom already in `scripts/stop.sh`) — the NSR round is 5/5 green.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md` — new
§3.5 (hall snapshot) and §3.6 (NSR round) rows.

### Files
- *(carried from the frozen CHANGELOG.md)*

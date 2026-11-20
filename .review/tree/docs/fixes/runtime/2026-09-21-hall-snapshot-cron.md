## runtime · unversioned · 2026-09-21 — the NorthStar gate runs nightly; the hall snapshot on the 08:00 loom

### Why
- the NSR gate and the hall snapshot had no place on the schedule

### Fix
- nornir runs the gate at 02:30 and the hall snapshot at 08:00

### Files
- bin/nornir-job-*.sh, config/cron.yaml.example

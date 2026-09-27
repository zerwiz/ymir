## runtime · unversioned · 2026-09-27 — the asken backstop mirrors the roll to Anchor

### Why
bin/nornir-job-asken-handoff.sh ran asken trigger with --no-anchor, so a scheduled roll refreshed HANDOFF.md on disk but never reached the Anchor memory plane. The job now runs without --no-anchor: the Anchor sync is time-bounded inside asken and skipped when Anchor is down, so the backstop mirrors the roll when it can and never blocks.

### Files
- `bin/nornir-job-asken-handoff.sh`
- `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md`
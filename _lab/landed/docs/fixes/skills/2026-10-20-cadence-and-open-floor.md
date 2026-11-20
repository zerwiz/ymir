## skills · unversioned · 2026-10-20 — cadence and the open floor

### What

The meeting renderer reads the house cadence (weekday, time, length) instead of assuming
Monday 09:00, names every participant on the proposed agenda, and ends the agenda with an
**open floor** before the close. The worktree also ships the cron entry the home references
and resolves the home through the one resolver.

### Verified

- A synthetic home with a cadence file renders the named weekday and time.
- The agenda contains the everyone line and the open-floor section.
- The cron guard finds every referenced script in the repo.

### Not verified

- No real transcript was processed; patent-bearing material remains held.

## snotra · unversioned · 2026-10-20 — first-run setup, generic and idempotent

### What

- `bin/time/snotra/snotra-init.sh` — `check`/`apply`: creates the meetings shelf, a
  blank operator template, the confidential register, the trello and cadence configs,
  the meeting-locations map, the framework and templates, and the Snotra cron block.
  It never invents a company, a participant, an NDA hash or a board.
- The installer's `snotra` step runs it; migration `0011-snotra-meetings` does the same
  for an existing home on update.
- Board and cadence are configuration: `hodd/identity/trello.yaml` names the board, the
  ten lists and the labels; `hodd/identity/cadence.yaml` sets the weekly weekday, time
  and length. Both are versioned; an unknown version is refused.
- The email band and the board name no longer hardcode our company.
- The public fix notes and feature pages were redacted of names, addresses and company.

### Verified

- `snotra-init apply` in a clean temporary home creates five config files, the framework,
  templates and cron; `check` reports 0 missing and is idempotent.
- The installed framework is the agnostic skill asset, not our private plan.

### Not verified

- A real new-user install after this PR is merged.
- Git history still contains the earlier named text; removing it is a destructive,
  operator-owned decision.

## agents · unversioned · 2026-09-27 — the terminal act writes the shelf the failsafe sweeps

### Why

The 2026-09-27 missed handoff (audited in plan 58, Phase 3): three errands
reached `done:` with zero wakes reaching Brokk. Root cause, measured: the spawn
brief's status contract (`state/<id>.status`) wakes Brokk only through the live
poller, while the handoff failsafe (`bin/agents/eindri-handoff.sh`) sweeps only
`$STATE/eindri-reports/` and `$STATE/eindri-questions/` — **never the status
shelf**. A worker that followed the status contract alone was invisible to the
very road built to survive a dead poller.

### The fix

1. `bin/agents/erindi-brief.sh` gains a `REPORT_SHELF` (`$STATE/eindri-reports/<id>.md`)
   and the status protocol teaches the terminal act: `done:` / `failed:` /
   `needs-decision:` appends its status line AND a one-line report to the swept
   shelf — the two lines are ONE act, never deferred. Every future errand's
   harvest lands where the failsafe actually reads.
2. The nornir asset documents the failsafe sweep row
   (`06:45 bin/agents/eindri-handoff.sh sweep`, any role) so the sweep is scheduled,
   not merely possible; the home's cron carries the row.
3. The full decree (re-arm catch-up, one-shelf-one-contract) stays in plan 58
   Phase 3 as the next increments.

galdr-reread: `nornir-jobs.md`.

### Files

- `bin/agents/erindi-brief.sh`
- `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md`
- `$YMIR_HOME/config/cron.yaml` (private home, named-file commit — the sweep row)
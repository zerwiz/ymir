## hlidskjalf · unversioned · 2026-11-24 — the Projects, Sessions and Cron panels mended

### Why

Fulla opened the panels at 1440 and 390 pixels and found them wrong. Projects counted the release, not the dev clone,
and broke words in half. Sessions still showed only Smíðja runs. Cron called a seat that cannot report LATE. The
header badge read "ho / un / d" at 390.

### What changed

- **Projects**: `bin/records/projects_status.py` now prefers the dev clone that shares this tree's remote and
  reports the whole clone, so `Ymir` counts every worktree, not one release directory. Headers and seat names do
  not wrap; below 700 px each project is a card (name, realm, seat, worktrees, PRs, CI, kit, sessions, health, next).
- **Sessions**: the all-tools sessions (plan 368) are the main view, with the next updates per project
  (`/api/sessions/updates`). Smíðja runs are one section below. A failed run reads FAILED, not DOWN.
- **Cron**: a seat whose runtime is too old to report is `UNREAD` ("<seat> cannot report: update it"), shown in the
  warn tone and left out of the needs count. `bin/time/nornir-status.py` owns the word.
- **Heimdall's own `@dev` jobs read LATE because they were missed.** The scheduler fired only on an exact `HH:MM`
  match. A scheduler that was retired (no session lock) or restarted by a release flip never saw its minute, and
  nothing ran it later. `bin/time/nornir-cron-start.sh` now catches up: a clock-time job with no run stamped today
  fires once, within `BROKK_CRON_CATCHUP_HOURS` (default 14) of its time. The stamp keeps today's date, so it cannot
  fire twice. The status resolver was reading the right log.
- **Header**: the hound badge no longer wraps.
- **Tests**: `.agents/tests/nornir-catchup.test.sh`.

### Not done

Two jobs are really FAILED and are not changed here. `learn-home` on heimdall exits 4 because `home-sync` refuses
to merge a dirty home (a file overlaps the incoming change); the home needs cleaning, not the script.
`daily-briefing` on the heart exits 1 because two drafts are older than two days, which is the briefing
doing its job; the drafts need sending or closing.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #931

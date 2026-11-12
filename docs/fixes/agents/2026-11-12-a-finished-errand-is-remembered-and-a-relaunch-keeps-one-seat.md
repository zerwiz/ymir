# A finished errand is remembered in the well, and a relaunch keeps one seat

**2026-11-12 · component: agents · `bin/agents/eindri-acclaim.sh`, `bin/agents/erindi-brief.sh`, `bin/agents/eindri-liveness.sh`, `bin/agents/einherjar-spawn.sh`**

## What was wrong

**The well did not hear what a worker did.** An errand finished, filed its report shelf and
woke Brokk. Nothing it learned reached the well, so the next worker started from nothing. The
Allfather, 2026-11-12: *"when they are DONE they need to remember what they have done to the well."*

**A relaunch opened a second pane beside a living worker.** The spawner's one-agent guard asked
`herdr agent-status`. Herdr has no such verb (`unknown command: agent-status`). The guard read
nothing and never refused. On the night of 2026-11-11 a relaunch seated `w5W` beside `w5K`, and
`w5X` beside `w5M`, which put two workers in one worktree twice.

## What it does now

- **The brief asks for the episode.** Every Definition of done (direct-PR, local-only,
  no-mistakes, scout) gains a step before the terminal act:
  `bin/records/mimir.sh observe "<what was built · the PR · the lesson · what is left>" --source eindri --task <id> --tags eindri,done --shape behaviour`.
- **Acclaim is the backstop.** On `--terminal done` or `failed`, `eindri-acclaim.sh` asks the
  well for an episode for that task since its launch day. If none exists, it prints a loud
  `WARNING` and writes a minimal episode from `--line` (tagged `unremembered`). A failed errand is
  remembered with its why. A well that does not answer never holds back the wake.
- **An abandoned errand is remembered.** When the liveness sweep calls a seat dead, it writes
  one episode with its verdict and evidence, once per death.
- **One seat per errand.** The guard now reads `herdr pane list` and finds every pane whose cwd
  is in the errand's worktree. A working agent is refused (exit 3). On `--relaunch`, a bare shell
  in the worktree is reused for the new launch, and no workspace is created beside it. An idle or
  finished agent is refused unless `FORCE_RELAUNCH=1`, which closes the old seat before the new one opens.

The dispatch-time memory first asked for was withdrawn at the Allfather's correction. A refused
model is already on the record in `<state>/model-allow.log` (see
`docs/fixes/model/2026-11-12-only-approved-models-spawn.md`).

## Proved

- `bash tests/test_acclaim_well.sh` → `4 ok · 0 failed`. It covers a forgotten episode warned
  and written, a worker's own episode honoured with nothing doubled, and a failed errand remembered.
- `bash tests/test_relaunch_one_seat.sh` → `5 ok · 0 failed`, against a fake `herdr`: working
  refused, idle refused, `FORCE_RELAUNCH` replacing, bare shell reused, and a fresh seat when none is left.
- Live dry-run on this box: `einherjar-spawn.sh helm-knows-itself --relaunch --dry-run` now says
  `refused: an agent is working … pane: w5M:p1 w5M claude working`, and the same holds for
  `no-helm-no-errand` (`w5K:p1`). These are the two errands that were doubled.

## Not done

- The episode check matches on the task id and the launch **day**, because `mimir.sh recall`
  takes a date, not an instant. An episode from an earlier launch of the same id on the same day counts.
- The two duplicate panes standing tonight (`w5W`, `w5X`) are not closed by this change. That is the operator's call.

## CHANGE LOG

- **2026-11-12** — Created (branch `eindri/flash-only`).

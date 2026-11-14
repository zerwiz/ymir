# The audit ships, and the reaper reads every tab

## What was wrong

Two faults, measured on one machine on 2026-11-14, and each made the other worse.

**The measurement was not a capability.** Answering "may this seat be let go?" meant a shell
loop pasted into a pane, run by hand, once. It printed panes and branches and left the
judgement to whoever was reading. That is not a door: it dies with the pane, and the next
hand writes it again and gets a different answer.

**The reaper could only see what the spawner raised.** `bin/seat/seat-reap.sh --sweep` walked
the `eindri-*` workspaces `einherjar-spawn.sh` creates. A worker the helm seats **by hand** —
a tab in his own workspace, the road `projects-and-companies.md` teaches — was invisible to
it. That day 36 agent panes stood on the machine, almost all finished, and the sweep could
name none of them.

**A third fault lived inside the first fix.** The obvious test for "did this seat make a
commit of its own?" is `git rev-list --count origin/main..HEAD`. It is **wrong**: the count
is zero for every branch that has already been merged, so every landed seat would be read as
a recon that filed no work. The planted fixture caught it before it shipped.

## What changed

- **`bin/seat/seat-audit.sh` (new).** One line per agent pane in every workspace and tab,
  carrying the runbook's four checks: folder clean, commits on origin, work landed
  (`origin/main`, or a PR GitHub reports `MERGED`), and the branch for the helm to read.
  TOON on stdout; `--tsv` for the machine face; `--pane`, `--no-pr`, `--fetch`.
- **The verdict is one implementation.** `landed` · `recon-with-report` · `recon-no-report` ·
  `unmerged` · `open-pr` · `open-pr-conflict` · `pr-closed` · `dirty` · `unpushed` ·
  `working` · `no-origin-main` · `no-git` — the runbook's own table, in one place.
- **GitHub answers mergeability, `git merge-tree` is never called.** It hung for 30 s with no
  CPU use on this repository. One `gh pr list --limit 1000` per repository, indexed by head
  branch; a batch shorter than the limit is complete, so a missing branch is a fact (`none`)
  and not a reason to ask twice. An answer GitHub cannot give reads `?`, never `none`.
- **`bin/seat/seat-reap.sh` reads the whole hall.** After the `eindri-*` stage it asks
  `seat-audit.sh` once and closes a hand-seated seat only on `landed` or
  `recon-with-report`. It closes the **workspace** when the seat owns one (`eindri-*`, so no
  empty workspace is left behind) and the **tab** otherwise. It never closes a pane herdr
  reports as `focused` — that is where the operator's hand is — and never a `working`, `dirty`
  or `unpushed` one. `SEAT_REAP_TABS=0` disables the stage.
- **Every close is recorded** as one dated line in `state/eindri-reports/<helm>.md`, the file
  the runbook names: pane, branch, verdict, and how it closed. The helm's name is read from
  the lease; `SEAT_REAP_REPORT` overrides the path.
- **`bin/seat/herdr-agents.py` gained `--tsv`**, so the pane, its tab and its workspace reach
  both doors through the one reader of `herdr agent list` instead of a second parser.

As a side effect of the same fix, a branch that made no commit of its own is no longer
credited with the hall's merges: `is_recon` asks two facts together — `origin/main` already
contains this HEAD **and** the branch exists on no remote.

## Proof

Two new wards, both on planted repositories with a bare remote, a main checkout and linked
worktrees per state, and a stubbed herdr and gh — nothing touches the real hall, `$HOME`,
GitHub or this repository's own worktrees.

- `bin/seat/tests/test_seat_audit.sh` — **35 ok / 0 fail**. Every row of the runbook's table
  plus the squash-merge case (`MERGED` while `HEAD` is not an ancestor of `origin/main`), the
  working-wins-over-landed case, the three skips, the `--tsv` shape (sixteen fields, no empty
  field: tab is whitespace to `read`), `?` versus `none`, the no-herdr clean skip, and a fence
  that `merge-tree` appears in neither door's code.
- `bin/seat/tests/test_seat_reap_tabs.sh` — **33 ok / 0 fail**. `--list` names the hand-seated
  tabs and closes nothing; `--sweep` closes the landed tab, the recon tab and the owned
  workspace, and never the working, dirty, unpushed, focused, main-checkout or self pane; the
  hall's own workspace is never closed; the report carries one dated line per close and no
  more; branches and worktrees survive; a second sweep closes nothing new.
- `bin/seat/tests/test_seat_reap.sh` — **70 ok / 0 fail**, unchanged: the `eindri-*` stage was
  not re-decided.
- Measured live on this machine before the docs were written: the audit read all 13 agent
  panes in 5.5 s with one GitHub call, named three working panes, two clean-but-unmerged
  worktrees and one dirty review pane, and skipped the four main checkouts and its own pane.

## Where it sits

Plan 293 parts 1–2 (`svartalfaheim/whynotproductions/projects/ymir/plans/`). The runbooks are
the specification: `hodd/docs/runbooks/retiring-finished-agents.md` and the 2026-11-14 section
of `hodd/docs/runbooks/fleet-to-fleet-communication.md`. The runtime asset that now carries the
contract is `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`; the user's page is
`docs/features/the-seat-audit.md`.

## CHANGE LOG

- **2026-11-14** — written with the change it describes, by the errand `reaper-reads-tabs`.

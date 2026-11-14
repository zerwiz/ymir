# The seat audit — may this worker's pane be closed?

## What it is

One command that answers, for every agent standing in a herdr pane on this machine,
whether its work is **safe** (on origin), **landed** (merged, or in a pull request the
heart accepted) and **clean** (nothing uncommitted) — and hands you the branch so you
can check whether it was **right**.

It exists because the answer used to be a shell loop pasted into a pane. That loop died
with the pane, and the next hand wrote it again and got a different answer. On
2026-11-14 one machine carried 36 agent panes and almost all of them were finished;
nothing could say which, so the helm measured them by hand.

The audit is the measurement. `bin/seat/seat-reap.sh` is the hand that acts on it, and
it now reads hand-seated tabs too — not only the `eindri-*` workspaces the spawner
raises.

> [!IMPORTANT]
> The audit tells you whether a pane **may** close. It does not tell you the work was
> right. Reading the branch — the diff against `origin/main`, the commit messages, the
> fix note, the worker's report against its brief — is still yours, and the runbook says
> it is never skipped: *"its critical to audit their work"*.

## What you need

- `herdr` — the pane backend. With no herdr the audit says so and stops; that is a clean
  skip, not a failure.
- `git`, and an `origin/main` on each repository you want measured. Without one a pane
  reads `no-origin-main` instead of a verdict.
- `gh` for the pull-request column. Without it, or with `--no-pr`, that column reads `-`
  and the door tells you it did not ask. A GitHub it *asked* and could not get an answer
  from reads `?` — never `none`.

## Do it

```bash
bin/seat/seat-audit.sh
```

The first line names the columns, then one line per agent pane in every workspace and tab:

```
seat-audit[3]{pane,status,agent,folder,branch,dirty,unpushed,in_main,pr,mergeable,verdict}:
  "w1:p1","working","pi","~/ymir/.yggdrasil/<errand>","eindri/<errand>","0","0","yes","none","-","working"
  "w1:p2","idle","pi","~/ymir/.yggdrasil/<errand>","eindri/<errand>","0","0","no","#123 OPEN","MERGEABLE","open-pr"
  "w2:p1","idle","claude","~/ymir/.yggdrasil/<errand>","eindri/<errand>","0","0","no","none","-","unmerged"
skipped[2]{pane,why}:
  "w1:pT","a repository main checkout — a seat, not an errand"
  "w1:p9","the caller's own pane"
```

**The verdicts**, each a row of the runbook's own table:

| Verdict | What it means | May the pane close? |
|---|---|---|
| `landed` | `HEAD` is in `origin/main`, or the PR is `MERGED` | yes |
| `recon-with-report` | no commit of its own, and its report is filed | yes |
| `recon-no-report` | no commit of its own and nothing filed | no — there is nothing to show |
| `working` | an agent is working here | never |
| `dirty` | uncommitted files | never |
| `unpushed` | commits no remote holds | never |
| `unmerged` | pushed, no PR, not in `origin/main` | not yet — gather it |
| `open-pr` | a PR waits for the heart | not yet |
| `open-pr-conflict` | the PR is `CONFLICTING` | not yet — rework |
| `pr-closed` | the PR closed without a merge | no — the heart decides |
| `no-origin-main` | `origin/main` is not fetched here | no — unmeasurable |
| `no-git` | the folder is not a git repository | no — not an errand's tree |

### Options

```bash
bin/seat/seat-audit.sh --pane w39:p1T   # one pane
bin/seat/seat-audit.sh --tsv            # the machine face: + tab, workspace, focused, why, report
bin/seat/seat-audit.sh --no-pr          # never ask GitHub
bin/seat/seat-audit.sh --fetch          # fetch origin first: a truthful unpushed count
```

`--tsv` is what the reaper reads. Its fields are tab-separated and never empty — a
missing value is `-`, because a tab is whitespace to `read` and an empty field would
shift every field after it.

### Letting the reaper do it

```bash
bin/seat/seat-reap.sh --list    # what a sweep would close; closes nothing
bin/seat/seat-reap.sh --sweep   # close what the runbook allows
```

`--sweep` runs the `eindri-*` stage it always ran, then asks `seat-audit.sh` once and
closes a hand-seated seat only when the verdict is `landed` or `recon-with-report`. It
closes the **workspace** when the seat owns one (the `eindri-*` shape, so no empty
workspace is left behind) and the **tab** otherwise. It never closes:

- a pane herdr reports as `focused` — that is where your hand is;
- a `working`, `dirty` or `unpushed` pane;
- a pane in a repository's main checkout, or the pane it is running from.

`SEAT_REAP_TABS=0` turns the tab stage off for one run.

### Where the record goes

Every close is one dated line in `state/eindri-reports/<helm>.md` — the file the runbook
names, with the helm read from the lease and `SEAT_REAP_REPORT` overriding the path:

```
- 2026-11-14T15:34:17Z — pane w39:pR · branch eindri/landed · landed · closed the tab
```

Ask "where did that agent's work go?" and you get one line back.

## Notes & limits

**Nothing is deleted.** No door here deletes a branch or removes a worktree. A merged
worktree is `bin/forge/housekeeping.sh`'s judgement, and it waits until the branch is
merged and no shell stands in it.

**`git merge-tree` is never called.** It hung for 30 seconds with no CPU use on this
repository. Mergeability is asked of GitHub — one `gh pr list` per repository, not one
per pane.

**GitHub is asked only about a pane that could close** — clean, pushed and not working.
A dirty, unpushed or busy seat is refused before its pull request matters, and a
network round trip per candidate is a cost this door pays at every session start.
Such a pane's `pr` column reads `-`, the same word `--no-pr` uses: not consulted.

**No fetch per pane.** The sweep runs at every session start. Without a fetch the
`origin/<branch>` ref can only *understate* what the remote holds, so a stale read
refuses to close a seat rather than closing one too early. `--fetch` takes the truthful
count, at the cost of a network round trip per pane.

**A local `main` is never consulted.** Every "landed" answer is measured against
`origin/main`. A machine whose local `main` has diverged still reads the truth.

**A merged branch with an unpushed commit reads `unpushed`.** That is not a bug: the
runbook's rule is that a commit no remote holds is never closed away, whatever else is
true of the branch.

## If it does not work

**`seat-audit[0]{state}: "no herdr on this host"`** — there is nothing to audit on this
machine. That is a clean skip.

**Every pane reads `no-origin-main`** — fetch the repository. The verdict needs
`origin/main`, and it will not guess from local `main`.

**The `pr` column reads `?`** — GitHub was asked and could not answer: no `gh`, no auth,
or no network. The `landed` verdict may then depend on `origin/main` alone, which misses
a squash-merged branch. Sort the auth out before closing anything on that pane.

**The `pr` column reads `none` on a branch you know has a PR** — the batch was complete
and did not carry it; check the branch name the PR was opened from (`gh pr view`).

**A pane you expected to close is kept** — read its `why` column in `--tsv`, or run
`seat-audit.sh --pane <id>`. Every refusal names its reason.

## Proven on this machine, 2026-11-14

`bin/seat/tests/test_seat_audit.sh` — **35 ok / 0 fail** — plants one bare remote, one main
checkout and ten linked worktrees (clean-merged, clean-unmerged, dirty, unpushed, working,
a recon with a report and one without, an open PR that conflicts, an open PR that waits,
and a squash-merged PR whose commits are *not* ancestors of `origin/main`), with a stubbed
herdr and a stubbed gh.

`bin/seat/tests/test_seat_reap_tabs.sh` — **33 ok / 0 fail** — plants eight panes in a
stubbed hall and proves what is closed and, more to the point, what is never closed.

`bin/seat/tests/test_seat_reap.sh` — **70 ok / 0 fail**, unchanged: the `eindri-*` stage was
not re-decided.

Measured live before the page was written: 13 agent panes read in 5.5 s with one GitHub
call, four main checkouts skipped, its own pane skipped.

## CHANGE LOG

- **2026-11-14** — written with the change it describes (plan 293 parts 1–2, the errand
  `reaper-reads-tabs`).

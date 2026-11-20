## runtime · unversioned · 2026-09-27 — Forseti, the judge sent after every ship (the automatic PR-review spine)

### Why
The delivery gate made a PR the only way work leaves — branch → worktree → tests →
`gh pr create` → Glitnir review → the Allfather seals. Half the gate was missing:
**nothing sent the judge.** A PR arrived at Brokk's desk already "done", and the
review was a hand-written errand the Allfather had to remember to dispatch (as with
`review-228/229/230`, whose brief was the charter). A gate that depends on someone
remembering to feed it is not automatic.

- **The spine.** `bin/agents/eindri-review-spawn.sh <task-id>` reads the PR from the
  task's own record (`state/<id>.status` carries `done: opened PR <url>`), fills
  the fierce review brief for THIS task (PR, branch, task id) from
  `.agents/assets/templates/review-brief.template.md`, and seats **Forseti** as a
  scout-kind `<id>-review` errand through the einherjar road:
  `--scout --backend herdr --harness pi --model opencode-go/deepseek-v4.1-flash
  --effort high`. The harness is the one the einherjar road launches for the
  figure, resolved from the roster (`bin/fleet/agents-config.sh get forseti harness`);
  the model is a per-machine choice with one documented default (Rule 07).
- **The trigger is the terminal act.** `bin/agents/eindri-acclaim.sh` — the worker's own
  finish line — now calls the spine from its `done` path, after the status line,
  shelf, and durable wake are written. No poller, no sweep: the same push path
  that wakes Brokk sends the judge.
- **One per task, and never silent.** A `.reviewed` marker
  (`state/.reviewed/<id>`) is written only after the judge is *seated*, so a
  re-done never re-reviews and a failed spawn leaves no marker (a retry can still
  seat the judge). A failed spawn queues a loud wake and sounds the alarm;
  `YMIR_AUTO_REVIEW=off` prints why and skips. A scout opens no PR, so the spine
  never reviews a review.
- **The judge never touches the branch.** Forseti's card keeps `edit: deny` /
  `write: deny`; the brief is read-only by charter, and the verdict's mandatory
  tail is the TOON `verdict[1]{result,count,list,seal}` block.
- **A seat's private state is not the wake road.** The spine writes the review's
  meta, status, ~ brief, and verdict to the SHARED state (the project's `state/`,
  beside the code), never the caller's per-seat `BROKK_STATE_OVERRIDE`; the
  generated review brief's terminal act carries the shared state explicitly, so
  the verdict reaches the shelf `bin/agents/eindri-handoff.sh` sweeps.
- **Where the record lives.** The verdict lands on the wake road at
  `state/eindri-reports/<id>-review.md` — the shelf guarded by the ack-eats-only-
  what-it-saw fix (PR #232).

### Files
- `bin/agents/eindri-review-spawn.sh` (new) — the spine: guards, PR/branch resolution,
  brief fill, the einherjar seat, the `.reviewed` marker, `--dry-run` /
  `YMIR_REVIEW_DRY`.
- `bin/agents/eindri-acclaim.sh` — the `done` path calls the spine; a failed spawn
  queues a loud wake (`.reviewed/<id>.failed`) and sounds the alarm.
- `.agents/assets/templates/review-brief.template.md` (new) — the fierce contract,
  parameterised (the charter exercised by review-228, made a template).
- `.agents/agents/forseti-reviewer.md` — Forseti seated as the review figure: the
  spine's charter and the `review_spine` capability; `edit: deny`/`write: deny`
  kept.
- `.agents/roles.yaml` — the reviewer role names the spine; `pr`/`pull request`/
  `ship` added to its keywords.
- `RULES/02-agents.md` — §6 appended: the review figure and the canonical-card law.
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md` — §7 documents
  the spine, its one-per-task marker, and the loud off switch.
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` — Part 2c
  added (the review spine under the Eindri push path) and §15's Forseti row updated.
- `.agents/skills/galdr-ymirsystem/assets/eindri-profiles.md` — Forseti's row names
  the automatic post-ship seat.
- `.agents/tests/eindri-review-spine.test.sh` (new) — the spine's regression test.

### Proof
- `bin/agents/eindri-review-spawn.sh litmus-ship --dry-run` (fixture with a PR) prints the
  exact line: `einherjar-spawn.sh litmus-ship-review <project> --scout --backend
  herdr --harness pi --model opencode-go/deepseek-v4.1-flash --effort high`.
- `bin/agents/eindri-acclaim.sh <id> --terminal done` with a PR-bearing fixture reaches
  that spawn (shown with `YMIR_REVIEW_DRY=1`); with `YMIR_AUTO_REVIEW=off` the same
  call prints the loud skip; with the `.reviewed` marker present it skips as
  "already reviewed"; a `kind=scout` task and a `-review` id both skip.
- `.agents/tests/eindri-review-spine.test.sh` → `ALL PASS`; `bash -n` clean on both
  scripts; the extension ABI is untouched (no `.pi/shared/extensions` change, no
  `bin/syn-*` or arm-grammar change).

galdr-reread: `brokk-distro-runtime.md` §7 (the worker model) and
`harness-integration/README.md` Part 2b/2c — load both before touching the push
path or the reviewer roster again.

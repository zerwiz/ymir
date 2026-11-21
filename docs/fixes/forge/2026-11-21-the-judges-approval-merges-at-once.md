# forge · 2026-11-21 — the judge's approval merges at once

## Files

- `bin/forge/judge-merge.sh` — new: reads the judge's verdict block and carries it out (`act`, `sweep`, `verdict`)
- `bin/agents/pr-seal.sh` — `seal <n> --repo <owner/repo> --head <sha>`: the judge's road, any PR in the house's repositories
- `bin/forge/review-watch.sh` — `--keeper`: a judge for every open PR head, one at a time; hand-off to developer seats
- `bin/agents/eindri-review-spawn.sh` — writes the judged record (repo, PR, head) before the judge starts; the home's judge row wins over an environment pin
- `bin/model/agent-model.sh` — a claude-harness agent's Claude name is honoured; a provider/model pin yields to it
- `bin/agents/eindri-acclaim.sh` — a review errand's `done` hands its verdict to `judge-merge.sh act`
- `.agents/assets/templates/review-brief.template.md` — the judge names the head it judged and knows an APPROVE merges
- `config/units.yaml` — the review clock runs every 3 minutes
- `bin/forge/tests/test_judge_merge.sh` — 34 fenced cases with a fake gh and a fake verdict
- `.agents/tests/eindri-review-spine.test.sh` — the spawn-line case pins its harness and model per run

## Why

The Allfather's word, 2026-11-21: *"We need to have a claude opus review every pr. If its OK. He merges
instantly."* RULES/08 gained two sections that night. The machinery was missing three pieces.

- **Nothing read the verdict.** The judge wrote `verdict[1]{result,count,list,seal}` to its report, and the
  approval waited there for a person.
- **Only an errand's own PR was judged.** A PR from another hand, or one whose head moved, got an ask at best.
- **The judge could not be seated as declared.** The home names it `harness claude, model opus`. The model
  resolver checks pi's catalogue, which never lists a Claude name, so it fell to the fleet default. On the
  heart a drop-in also pinned `YMIR_FORSETI_MODEL` to a pi model. Either way the claude harness refused
  the spawn (`harness 'claude' cannot serve model 'opencode-go/deepseek-v4.1-flash'`).

## Fix

**One road from verdict to merge.** `judge-merge.sh act <review-id>` reads the verdict. APPROVE calls the one
merge door, `pr-seal.sh seal <n> --repo <r> --head <approved sha>`. That door re-checks at the instant of the
merge: the repository is in the registry's git blocks, `gh api user` is its owner, the head is the approved
head, every check SUCCESS and none pending, mergeable, no draft, no `hold` label, no `state/.seal-hold`. It
merges with the method from `merge-method.sh`, a written body (never GitHub's default trailers),
`--match-head-commit`, and one Rune.

**A red or pending gate does not merge.** Red posts one comment naming the failing row and settles that head.
Pending posts one comment and stays unsettled, so the same approval merges once the gate turns green.

**NEEDS-REWORK goes home.** One PR comment carries the items. The arm holder of the seat that opened the PR
(its `Arm:` line, else this seat) is told by two roads at once: the arm wire and a turn typed into its herdr
pane. The line asks it to start a coder errand on the PR's branch. The coder's new head is judged again.

**The keeper.** `review-watch.sh --keeper` (the default on the heart) watches every repository in the
registry's git blocks. Each open, non-draft PR with no judged record for its current head gets the judge,
one at a time, in a herdr pane on that repository's clone. While a judge is in flight, or on a machine with
no CLI for the judge's harness (the heart has no claude), the review is handed to a developer seat, again by
the arm wire and the pane. Each pass first sweeps the written verdicts.

**The judge's model.** For a claude-harness agent the row's Claude name is used as written, and an
environment pin naming a provider/model token yields to it with a named finding.

A stale report cannot approve a new head: the judged record is written before the judge starts, and a report
older than it, or naming a different `judged-head:`, is never read as approval.

## Proof

- `bash bin/forge/tests/test_judge_merge.sh` → `judge-merge: 34 passed, 0 failed`
- `YMIR_FORSETI_MODEL=opencode-go/deepseek-v4.1-flash bin/model/agent-model.sh forseti --json` → `"model":"opus","source":"agents row (harness claude)"`
- `eindri-review-spawn.sh --pr <url> --dry-run` under the same pin → `--backend herdr --harness claude --model opus`
- `.agents/tests/eindri-review-spine.test.sh`: the spawn-line case passes; five brief cases fail exactly as they do on `main` (the data shelf moved on 2026-11-20) and are not this change's.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #863

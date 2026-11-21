# The judge merges — every PR reviewed, an approval merged at once

## What it is

Every pull request in the house's repositories is reviewed by the judge (the figure `forseti`, set in your
home's `config/agents.yaml`). When the judge approves and every gate is green, the PR is merged at once. When
the judge asks for rework, the items go back to whoever opened the PR, and the next head is reviewed again.

The law is RULES/08, its two sections appended 2026-11-21.

## What you need

- `gh` signed in as the owner of the repositories (the registry's `git.owner`). Any other login is refused.
- Your repositories listed with a `git:` block in `hodd/identity/projects.yaml`, and a local clone named by
  `local_clone` or `repo` for each one the judge should read.
- The judge's harness CLI on at least one developer seat. The machine that keeps the watch may lack it; it
  then hands each review to a developer seat.

## The commands

```bash
bin/forge/review-watch.sh --keeper --dry-run   # what the keeper would seat or hand off now
bin/forge/review-watch.sh --keeper             # one pass: carry out verdicts, seat or hand off judges
bin/forge/judge-merge.sh sweep --dry-run       # what each written verdict would do
bin/forge/judge-merge.sh act pr-42-review      # carry out one review's verdict
bin/agents/pr-seal.sh seal 42 --repo owner/repo --head <sha>   # the one merge door the judge uses
bin/model/agent-model.sh forseti --explain     # which model the judge gets on this seat
```

The keeper runs on the review clock (`review-watch` in `config/units.yaml`, every 3 minutes). On the heart
it is the default road; elsewhere set `YMIR_REVIEW_KEEPER=1`.

## What happens to a verdict

| Verdict | Gates | What happens |
|---|---|---|
| APPROVE | all green | merged at once: squash with a written body (a gathered batch takes a merge commit), pinned to the approved head, one Rune |
| APPROVE | red | no merge; one comment names the failing check; the next head is reviewed again |
| APPROVE | pending | no merge yet; one comment; the same approval merges when the gate turns green |
| APPROVE | head moved | no merge; the new head is reviewed |
| NEEDS-REWORK | any | one comment with the items; the opener's arm holder is told (arm wire and its pane) to start a coder errand |

## Limits

- `state/.seal-hold`, a `hold` label or a draft stops every merge.
- One judge runs at a time on a machine; the rest are handed to developer seats.
- You can still merge anything from your hall yourself.

## If it does not work

- `wrong identity` — `gh api user` is not the repository's owner. Sign in as the owner, or set
  `YMIR_MERGE_IDENTITY` for an organisation repository.
- `no local clone … is named in the registry` — add `local_clone:` to that project's row.
- The judge never starts on a machine — `command -v claude` is empty there; the keeper hands off instead. Check
  `bin/fleet/arm-send.sh --who` for a developer seat holding the arm.

## CHANGE LOG

- 2026-11-21 — first written: the judge reviews every PR head, and an approval on green merges at once (RULES/08).

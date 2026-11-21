# The judge and the coder are handed the same kit

**Date:** 2026-11-21 · **Component:** seat · **Doors:** `src/ymir_runtime/figure_card.py` (new), `bin/seat/figure-card.sh` (new),
`bin/agents/read-first.sh` (new), `bin/agents/plan-claims.py` (new), `bin/agents/erindi-brief.sh`, `bin/agents/cmd-limit-lib.sh`,
`bin/agents/eindri-review-spawn.sh`, `bin/agents/einherjar-spawn.sh`, `.agents/assets/templates/review-brief.template.md`,
`src/ymir_runtime/seat.py` · **Tests:** `bin/agents/tests/test_judge_coder_kit.sh`, `src/ymir_runtime/tests/test_role_config.py`

## What was wrong

Measured on 2026-11-21: the figure cards (`forseti-reviewer.md`, `sindri-developer.md`, …) were never given to a seat; the
house's books for the code a worker touches never reached it; the coder's rule 1 still said the human gate owns the merge;
the judge never saw the plan a PR claims; and the judge's brief lacked the command limit, the ssh rule, the talk door and
the stall rule.

## What changed

- **The figure card opens the seat's prompt on every harness** (the engine road and the shell road both prepend it; pi and
  opencode read the same prompt file as Claude). Role to figure: judge `forseti`, coder `sindri`, scout `kvasir`, helm `brokk`.
- **Read first**: `read-first.sh` turns `bin/records/where.sh` rows for the paths a task names (or a PR changes) into a list of
  paths, never pasted text. The coder's brief scaffold takes `--paths`; the seat's prompt adds the list at spawn. The judge's
  list adds the compliance gate.
- **Rule 1 rewritten** to RULES/08 as of 2026-11-21 in every ship mode; the done gates no longer route to a human seal.
  Rules 9 (`bin/agents/tell.sh`) and 10 (the stall watch) join 7 and 8, rendered by `worker_rule_lines` for both briefs.
- **The judge sees the plan**: `plan-claims.py` reads the PR body, the branch's fix note and the errand brief and answers with
  plan files; a plan with no file is named, never dropped.

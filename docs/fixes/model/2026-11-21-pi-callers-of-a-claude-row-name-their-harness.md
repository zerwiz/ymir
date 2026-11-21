# Pi callers of a Claude row name their harness

**Component:** model · **Date:** 2026-11-21

## What was wrong

The first fix in PR #865 (`2026-11-21-a-claude-row-is-judged-by-claude.md`) made a `harness: claude` row
resolve to a Claude name. The Opus judge found that some callers of the `forseti` row run **pi**:

- `bin/ward/vidarr-agent.sh`, `bin/ward/garmr-bite.sh` and `bin/ward/garmr/escalate.py` ask for `--tier strong`;
- `bin/forge/review-seat.sh` seats its reviewer with `herdr agent start reviewer --kind pi`.

`agent-model.sh` ignored `--tier` on a Claude row. So these callers would have handed `pi --model` a Claude
name, and it would have failed later and further from the cause.

## What changed

| File | Change |
|---|---|
| `bin/model/agent-model.sh` | `--tier` on a Claude row with no `--harness` is refused by name (exit 3). The refusal names the fix: `--harness pi`. |
| `bin/ward/vidarr-agent.sh`, `bin/ward/garmr-bite.sh`, `bin/ward/garmr/escalate.py` | Ask for forseti with `--harness pi`. |
| `bin/forge/review-seat.sh` | Asks with `--harness pi` on purpose, because the seat runs pi. The per-PR Claude judge is still seated by `bin/agents/eindri-review-spawn.sh`. |
| `bin/forge/smith-seat.sh`, `bin/agents/syn-judge.sh` | Pi seats; they ask with `--harness pi` as well. |
| `tests/test_agent_model_claude.sh` | 17 cases. The new ones cover `--harness pi` on a Claude row, `--tier` with and without a harness on a Claude row, and a check that each pi caller of forseti names its harness. |

## Proof

On the dev machine:

- `agent-model.sh forseti --harness pi --tier strong --plain` prints `opencode-go/deepseek-v4.1-flash`.
- `agent-model.sh forseti --tier strong --plain` is refused, with exit 3.
- `eindri-review-spawn.sh --pr …/pull/860 --dry-run` still produces `--harness claude --model claude-opus-5-5`.
- Tests: `test_agent_model_claude.sh` 17/17, `test_review_spawn_data_home.sh` 13/13, `test_model_allow.sh` 18/18.

> [!IMPORTANT]
> On the heart, the pin `YMIR_FORSETI_MODEL` in `review-seat.service.d/30-approved-model.conf` belongs to
> the **pi** review seat and must stay a pi model. The earlier note said to change it; that was wrong.

# A Claude row is judged by Claude's list, not pi's catalogue

**Component:** model · **Date:** 2026-11-21

## What was wrong

RULES/08 names the judge as Claude Opus, so the home's `agents.yaml` reads
`forseti: { model: opus, harness: claude }`. `bin/model/agent-model.sh` checked every row against
pi's catalogue (`bin/model/catalog.sh`), and pi never lists a Claude model. So the resolver printed
`FINDING — overlay … names opus for 'forseti', which THIS seat does not list; falling through` and
returned the fleet default, a pi model.

`bin/agents/eindri-review-spawn.sh` then handed Claude that pi model, and `einherjar-spawn.sh`
refused it: `harness 'claude' cannot serve model 'opencode-go/deepseek-v4.1-flash'`. No judge was
seated for any PR.

## What changed

| File | Change |
|---|---|
| `bin/model/agent-model.sh` | A row whose harness is `claude` resolves through `bin/seat/claude-seat.sh model`, which reads the allow-list. The answer is the name the Claude CLI accepts (`claude-opus-5-5`). New flag `--harness`; `--json` and the TOON row now carry the harness. |
| `bin/agents/eindri-review-spawn.sh` | Passes `YMIR_REVIEW_HARNESS` to the resolver when set, and prints the resolver's refusal instead of hiding it. |
| `bin/agents/eindri-start.sh` | Passes `--kind` to the resolver as the harness. With no `--kind`, a role whose row runs on Claude is seated on Claude. |
| `tests/test_agent_model_claude.sh` | Ten cases, listed below. |

The harness comes from `--harness`, then the overlay row, then the fleet row. For a Claude row:

- `--model`, `YMIR_<AGENT>_MODEL` and the row's `model` must be a Claude model (an id or the alias
  `opus`, `sonnet` or `haiku`).
- A Claude row that names a pi or opencode model is **refused by name** (exit 3). It never falls
  through to a pi model.
- A Claude row with no model takes the allow-list's Claude default.

Pi and opencode rows are unchanged and still answer to pi's catalogue.

## Proof

```
bin/agents/eindri-review-spawn.sh --pr https://github.com/zerwiz/ymir/pull/860 --dry-run
… einherjar-spawn.sh pr-860-review … --scout --backend herdr --harness claude --model claude-opus-5-5 --effort high
```

`bin/model/agent-model.sh --check` on the dev machine: 10 ok, 0 fail, with `forseti` resolving to
`claude-opus-5-5`.

`tests/test_agent_model_claude.sh` checks ten cases:

- opus on claude resolves to `claude-opus-5-5`;
- a Claude row with a pi model is refused by name;
- a Claude row with no model gets the Claude default;
- a pi model in the environment override is refused for a Claude row;
- a Claude model in the environment override is honoured;
- `--harness claude` judges a row that names no harness;
- a listed pi row resolves;
- an unlisted pi row falls through with a finding;
- `opus` on a pi row is still judged by the catalogue;
- `--json` carries the harness.

## What is still owed on the heart

> [!IMPORTANT]
> The heart pins the judge to a pi model in two places. The resolver now refuses both by name
> instead of quietly running on the wrong model:
>
> - the drop-in `review-seat.service.d/30-approved-model.conf` sets `YMIR_FORSETI_MODEL` to a pi model;
> - the heart's own overlay names a pi model for `forseti`.
>
> The heart also has no `claude` CLI on its PATH. Until one is installed, a Claude judge cannot be
> seated there, whatever the config says.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #865

## Appended 2026-11-21 — the judge's rework (PR #865, three items)

The Opus judge returned NEEDS-REWORK. Its findings and what was done about each:

1. **`--tier` was silently dropped on a Claude row.** The pi callers of the forseti row
   (`bin/ward/vidarr-agent.sh`, `bin/ward/garmr-bite.sh`, `bin/ward/garmr/escalate.py`) ask for
   `--tier strong` and run `pi`. They would have been handed a Claude name. Two changes:
   - those callers now pass `--harness pi`;
   - `--tier` on a Claude row without `--harness` is refused by name (exit 3).
2. **`bin/forge/review-seat.sh` seats the reviewer on pi** (`herdr agent start reviewer --kind pi`)
   but asked for forseti without naming a harness. It now passes `--harness pi` on purpose. The
   per-PR Claude judge is still seated by `eindri-review-spawn.sh`, which reads the row's harness.
   The other pi seats that resolve a role (`bin/forge/smith-seat.sh`, `bin/agents/syn-judge.sh`)
   pass `--harness pi` too.
3. **Tests.** `tests/test_agent_model_claude.sh` now has 17 cases. The new ones cover
   `--harness pi` on a Claude row, `--tier` with and without `--harness` on a Claude row, and a
   check that each pi caller of forseti names its harness.

> [!IMPORTANT]
> **A correction to "What is still owed on the heart" above.** The heart's
> `review-seat.service.d/30-approved-model.conf` pins `YMIR_FORSETI_MODEL` to a pi model, and it
> sits on the **pi** review seat. With `--harness pi` that pin is right and must stay. Setting it to
> a Claude model would make the pi seat refuse to start. The heart still owes two things for the
> Claude judge: its overlay's `forseti` row (a pi model under the fleet's `harness: claude`), and a
> `claude` CLI.

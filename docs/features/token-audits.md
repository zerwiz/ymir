# Token audits — Andhrímnir, the token economist

## What it is

Andhrímnir is a read-only auditor for how the house spends tokens. He measures what every agent loads before it starts, how often the prompt cache is hit, how many seats work on one change, which model each role runs, and how often work is retried. Then he ranks each saving by its measured size and names the fix and who owns it.

He never edits anything. A worker builds the fixes he names.

## What you need

- Ymir installed, with the agents you want audited seated on this machine.
- For cost per task: a harness or provider that reports token usage. Where none does, the report says "not measured" and names the command that would measure it.

## How to run it

Ask your arm holder for a token audit, or send the figure with your agent runner:

```
bin/agents/agent-run.sh andhrimnir "Audit this house's token use and write the report"
```

The skill he follows is `andhrimnir-tokens`. Find it with:

```
bin/agents/skill-find.sh "token audit"
```

## What you get

A report in your home, `hodd/docs/audits/<date>-tokens.md`, with one row per finding:

| Finding | Where | Measured spend | Saving if fixed | Fix | Owner |
|---|---|---|---|---|---|

Findings are ranked by saving. Anything that would trade away quality (a weaker judge, a skipped test) is listed separately for you to decide.

## Limits

- He measures and recommends; he does not change prompts, models or seats himself.
- Numbers come only from what the harness or provider reports. An unreported spend is marked, never guessed.

## If it does not work

- `skill-find.sh` does not find the skill: run `bin/agents/skill-find.sh --check` and fix the description it names.
- The report has many "not measured" rows: turn on usage reporting in the harness, or point him at a provider log.

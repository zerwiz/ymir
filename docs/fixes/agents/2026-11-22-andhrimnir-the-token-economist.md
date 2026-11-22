# Andhrímnir, the token economist, audits where the house spends tokens

**Component:** agents · **Date:** 2026-11-22

## What was missing

The house had no one whose craft was spending fewer tokens. On 2026-11-21 one night cost 87 seats and 71 judgements for about 20 pull requests, every seat loaded the house contract twice, and every worker connected 21 tool servers it never called. Those were found by hand.

## What changed

- A new figure, `.agents/agents/andhrimnir-tokens.md` (Andhrímnir, who feeds the hall from one boar). He is read-only: he measures, ranks and recommends.
- A new skill, `.agents/skills/andhrimnir-tokens/SKILL.md`: the checklist (seats and their prefix, cost per task, cache, seats per change, model per task, tool output and history), the report shape, and the sources it rests on (prompt caching, context engineering, cost per task, model routing, compaction, multi-agent cost).
- The skill index and `config/agents.yaml.example` name him; his default model is the house's cheap model.
- A feature page, `docs/features/token-audits.md`, and its catalogue row.

---
name: andhrimnir-tokens
description: "Token optimisation and token audits for an agent house — measure the cost of one finished task, the context each seat loads, cache hits, tool and MCP weight, duplicate seats, model choice and retries; rank the savings and name each fix. Use when asked to spend fewer tokens, to audit token use or cost, to make agents cheaper, or to check prompt caching. Keywords — tokens, cost, budget, cache, prompt caching, context, compaction, model routing, audit, optimisation."
---

# Andhrímnir — token optimisation and token audits

The figure is `.agents/agents/andhrimnir-tokens.md`. This is his checklist. Every row ends in a
number or in "not measured — run <command>".

## The best practice this rests on (read 2026-11-22)

| Practice | Source |
|---|---|
| Prompt caching is a prefix match; any changed byte invalidates everything after it; render order is tools → system → messages, so stable content goes first | Anthropic, *Prompt caching* (platform docs) and the `anthropics/skills` prompt-caching note |
| Context engineering: the smallest set of high-signal tokens that does the job; tools pull more context in on need | Anthropic, *Effective context engineering for AI agents* (2025-09-29) |
| Price the whole task (uncached input, cache writes, cache reads, output, summed over every request), and track cost per successful outcome | AWS ML blog, *How Airbnb uses cost per task to operate coding agents* (2026-11-18); validation-gated routing write-ups |
| Route each task to the cheapest model that passes its check; escalate on failure | *Task-to-Model Optimization for Enterprise LLM Coding Assistants* (arXiv 2608.08528) |
| Compact long histories at a declared context budget; keep what is cut recoverable | OpenAI, *Compaction* guide; *Context Compression for LLM Agents* (EMNLP 2026 survey) |
| Multi-agent systems cost many times a single chat; split only for clean context, real parallelism or a specialist | Anthropic, *How we built our multi-agent research system*; Cognition, *Don't Build Multi-Agents* |

## The audit, in order

1. **Seats and their prefix.** For each harness the house seats (pi, Claude Code, OpenCode, and the
   rest): the bytes of every always-loaded file (contracts, `CLAUDE.md`, `AGENTS.md`, digests), the
   number of tools and MCP servers connected and their schema weight, and the brief. Flag a file
   loaded twice and a server connected but never called.
2. **Cost per task.** For a sample of finished errands, judges and chats: requests per task, and the
   four token kinds per request, summed. Where the harness or provider reports usage, read it; where
   it does not, say so.
3. **Cache.** Cache hit rate per seat, and the first byte that changes between turns (a timestamp in
   a digest, a reordered tool list, a session id in the system prompt).
4. **Seats per change.** Writers, judges and helpers per PR; duplicates (two judges on one head, a
   judge of a judge, a new coder per rework round).
5. **Model per task.** Which model each role ran, and whether a cheaper one passes the same check;
   retries per task.
6. **Tool output and history.** The largest tool results fed back into context, and whether the
   history is compacted at a budget.

## The report

`hodd/docs/audits/<YYYY-MM-DD>-tokens.md` in the operator's home, written for a person (RULES/52):

| Finding | Where | Measured spend | Saving if fixed | Fix | Owner |
|---|---|---|---|---|---|

Ranked by saving, largest first. A trade-off against quality is its own section, for the operator.

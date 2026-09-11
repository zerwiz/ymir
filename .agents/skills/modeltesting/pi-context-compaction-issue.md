# pi context ceiling + MCP bloat + compaction degradation — diagnosis & plan

**Status:** investigated 2026-09-06 · **not fixed yet** — this is the working
plan for fixing three linked problems in pi's local llama.cpp sessions.

## The three problems (they stack)

### 1. Context ceiling: pi's window vs the server's real budget

pi picks when to compact from the model's `contextWindow` in
`~/.pi/agent/models.json`. But llama.cpp reserves the **output tokens inside the
same `n_ctx` budget**: a request fits only if

```
prompt_tokens + max_output_tokens <= server n_ctx
```

| | value |
|---|---|
| iq3 server n_ctx | 100 096 |
| pi `contextWindow` (restored) | 90 000 (≈92%) |
| headroom before output | ~10 000 tokens |
| generation budget at 90k prompt | 0 — **400 `exceeds_context`** |

A near-full prompt (say 85–90k) + a long generation → the server returns
`{"error":"exceeds the available context size"}` → pi treats it as a model
failure and **falls back**.

### 2. MCP tool-schema bloat: wayofteams dumps thousands of tokens per call

The wayofteams MCP `get_tool_schema` responses are **huge JSON** (the
`ideas_*` schemas seen in the session: `ideas_get`, `ideas_vote`,
`ideas_link_ticket`, … with multi-line descriptions). Every tool call /
schema fetch re-injects thousands of tokens into the context. In the failing
session pi was repeatedly dumping these:

```
get_tool_schema → {"description":"Toggle the authenticated user's vote on an idea","inputSchema":{...}}
get_tool_schema → {"description":"Link a tenant-local ticket to an idea", ...}
[compaction] Compacted from 73,677 tokens
get_tool_schema → ...
[compaction] Compacted from 74,762 tokens
```

### 3. Compaction degradation: pi "works less and less" after every compaction

The user's observation: after each compaction pi can do **less and less**. Root
cause hypothesis (to confirm):

- Each compaction replaces the raw history with a **summary**, but the summary
  is still re-injected alongside the (growing) system prompt, MCP tool schemas,
  and the new conversation.
- If compaction drops the token count but the **fixed overhead** (system +
  MCP schemas + tool definitions) is large, the *usable* headroom for actual
  work shrinks every cycle → pi feels progressively dumber / more error-prone.
- Worse: after compaction the context may still be **close to the ceiling**
  (compaction target is a % of window, not an absolute), so the next MCP dump
  or long generation immediately re-hits the 400 error → fallback again.

## What to fix (plan — needs operator sign-off per item)

| # | Fix | Owner | Risk |
|---|---|---|---|
| 1 | **Lower pi `contextWindow`** to leave output room — but the user chose to keep ~92% (round numbers), so instead fix the SERVER side: raise `n_ctx` where VRAM allows (q2 155k already max; iq3/4/5 at their sweet spots) OR cap pi's `max_tokens` output | pi/factory | medium |
| 2 | **Trim wayofteams MCP schemas**: the MCP server should return compact `inputSchema` (short descriptions) or pi should not re-fetch full schemas every tool call | wayofteams MCP | medium |
| 3 | **Absolute compaction target**: pi should compact to a **fixed headroom below the ceiling** (e.g. leave 20k for output + MCP), not a % that leaves it near-full | pi | low |

## Immediate mitigations (safe, no pi internals)

1. **Restart pi** when a session has compacted 2–3 times (the degraded state
   resets).
2. **Disable the heavy wayofteams MCP tools** for pi sessions that don't need
   them (or the whole MCP server) — removes the schema dump from every turn.
3. **Prefer the bigger-context models** for long sessions: q2 (155k server,
   140k pi window) instead of iq3 (100k) when the task + MCP schemas are large.
4. **Keep the ~92% windows** (restored) — the ceiling error is better fixed by
   trimming MCP overhead + restarting on degradation than by shrinking the
   window (which just makes pi dumber sooner).

## Files touched (this investigation)

- `~/.pi/agent/models.json` — windows restored to original round/92% values
  (the temporary 70% experiment was reverted per operator decision)
- `~/command/.pi/models.json` (Telegram pi) — already had correct 92% windows,
  no change needed
- This document

## Open questions

- Does pi's compaction target a % or an absolute? (affects fix #3)
- Can the wayofteams MCP server emit compact schemas / a schema cache key?
- Should pi's `max_tokens` output be capped lower on 100k-ctx models?
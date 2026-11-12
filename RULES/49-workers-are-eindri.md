# Rule 49 — Workers are Eindri; no harness spawns its own subagents

**Appended 2026-11-10, by the Allfather's word:** *"Claude Code never spawns its own subagents —
workers are Eindri."*

## The law

1. **Every worker is an Eindri.** Workers are spawned as Eindri: `bin/agents/eindri-start.sh` (or
   `bin/agents/agent-run.sh <figure> "<task>"`), seated on a Yggdrasil worktree, inside an Utgard
   sandbox when the work is untrusted, and armed. That is the only worker road the house recognises.
2. **No harness spawns its own subagents.** Claude Code must never use its `Agent` or `Task` tool.
   The same holds for any harness's private worker mechanism: it produces a second, invisible worker
   tree beside the house — no worktree, no sandbox, no Rune, no seat the Allfather can find, and no
   record when it ends.
3. **The refusal is mechanical, for every Claude seat in the fleet.** `.claude/hooks/eindri-only.sh`
   is a `PreToolUse` hook on `Agent|Task`. It **denies** the spawn and names the Eindri road, so the
   model reads the refusal as an instruction. `bin/seat/harness-extensions-install.sh` copies it to
   `~/.claude/hooks/` and adds it as ONE named user-scope `PreToolUse` entry, so it reaches a
   session in **any** project. The install seats it, Gróa's update (which runs that installer)
   re-verifies it, and Eir's `claudehooks` surface fails when it is stale.
4. **A worker that cannot reach the Eindri road does the work inline, or asks the Allfather.** It
   never falls back to a harness-private subagent. If no Eindri road works, doing the task in the
   main session is honest; spawning a shadow worker is not.
5. **The law is stated where a Claude agent reads it.** Appended under *Dispatch-first* in
   `AGENTS.md` (which `CLAUDE.md` imports), and cross-referenced from `RULES/02-agents.md`.

## Why

A harness subagent is not a seat: nothing about it is recorded, it is not on a worktree, it is not
sealed by Utgard, and it disappears with the turn. The house cannot review what it cannot find, and
the Allfather cannot steer what was never seated. The army is the Einherjar; the workers are Eindri.

## Where it lives

- `RULES/02-agents.md` — the agents contract this rule sharpens (cross-linked).
- `.claude/hooks/eindri-only.sh` — the ward (deny and name the road).
- `.agents/migrations/0021-the-claude-hooks.sh` — seats it into a home installed before this rule.
- `bin/seat/harness-extensions-install.sh` — the one owner of the wiring.
- `bin/agents/eindri-start.sh`, `bin/agents/agent-run.sh` — the Eindri road the refusal names.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.

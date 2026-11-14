## hlidskjalf · unversioned · 2026-11-14 — Stats reads every harness, and stops lying

Plan 275 item 29, at the Allfather's word: *"the stats aren't reading claude."*

### Why

`/api/usage` ran `bin/desktop/hlidskjalf-usage.sh`, whose sources were **only** opencode
(`opencode.db`) and pi (`~/.pi/agent/sessions`). Claude Code's sessions — 49 sessions, 228 MB on
heimdall, carrying `message.model` and `message.usage` — were never read, nor Codex, Cursor or
Hermes. And nine numbers on the page were not true (plan 275, 04:35): every **message** counted as
a successful **run** (61,103 runs, 100 %); two tables pricing the same tokens two ways (Online
$0.0000 beside Actual $82.00); cache read summed per call and compared against `input + output`,
a different quantity; "Avg CHR / run" computed on a field that is always empty (0.0 %); the
commercial comparison receiving no totals ($0.00); "local (pi, LM Studio, Ollama)" — LM Studio is
retired and pi is a harness, not a place a model runs; Local calls = Local sessions; By chain rows
that were harnesses with no model; By workflow rows that were model names; and an agent column
that was always "—".

### What changed

`hlidskjalf-usage.sh` v2.0.0 reads **every** harness from its own store:

| Harness | Store | Read as |
|---|---|---|
| opencode | `~/.local/share/opencode/opencode.db` | one SQL statement, `session_id` distinct = runs |
| pi | `~/.pi/agent/sessions/**`, `~/.pi/sessions/**` | one jsonl = one run |
| **Claude Code** | `~/.claude/projects/**/*.jsonl` | `message.usage`, **deduplicated by `message.id`** |
| **Codex** | `~/.codex/sessions/**/rollout-*.jsonl` | `token_count` → `total_token_usage`, **last per rollout** (it is cumulative) |
| **Hermes** | every `state.db` (`~/.hermes`, Bilskirnir's engine homes) | `session_model_usage` |
| Cursor | `~/.cursor` | probed; no usage store today, so a **named skip**, never a zero |

One meaning per number: a **run is a session** (messages reported beside it); success/fail are
`not recorded` where no harness states them, rather than counted as successes; cache read is
labelled *billed per call* and its ratio is taken against `input + cache_read`; **cost follows one
rule — recorded → published list price → `null`**, and an unpriced online model reads *not priced*
instead of `$0.0000`; local vs online is decided by **where the model ran** (the registry), not by
the harness; `local calls` and `local sessions` are now different numbers; the group-bys are
*By harness* and *By model*; and every row carries its harness as the agent.

`src/gates/Stats.tsx` was rewritten against that shape: the harness table shows each source and
what it was read from (with the skip reason), the runs panel says `not recorded` out loud, the
commercial comparison is computed **from the totals** (uncached, cached and output priced at the
vendor's own rates against what was actually paid), and the local label now names the rail.

### Proof

`bin/desktop/hlidskjalf-usage.sh` on heimdall, 30-day window, 6.9 s: **opencode 2,366 messages /
20 sessions · pi 36,400 / 252 · claude 7,105 / 69 · codex 51 / 1 · hermes 211 / 17 · cursor
skipped (no usage store)**. 359 runs, 46,133 messages, cost `$4020.14` with 2,543 unpriced calls
stated. Rendered in the real window (CDP) with Claude's rows and models visible
(`claude-opus-5-5 27 sessions · $3878.96`, `claude-sonnet-5-5 26 · $86.18`). `tsc --noEmit` clean.

### Files

`bin/desktop/hlidskjalf-usage.sh` · `apps/hlidskjalf/src/gates/Stats.tsx` ·
`apps/hlidskjalf/src/services/api.ts` (the `YmirUsage` shape).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #757

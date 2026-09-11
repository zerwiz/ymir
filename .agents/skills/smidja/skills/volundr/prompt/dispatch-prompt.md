# Kaia dispatch prompt template

Used by `factory/factory_orchestrate.py` to hand the WHOLE task to the orchestrator
with her memory of the project already injected. Fill the three variables,
then give it to Kaia (as the system prompt + this dispatch):

```text
OBJECTIVE (the original ask, unchanged):
{{objective}}

PROJECT: {{project}}
WHAT YOU REMEMBER ABOUT THIS PROJECT:
{{memory}}
```

- `{{objective}}` — the original ask, verbatim. Never summarize it.
- `{{project}}` — `Path(run.repo_root).name` (the repo basename).
- `{{memory}}` — the `kaia_memory_for(project, k=5)` recall: top hits' contents
  joined as `- <content>` bullets; or `(no prior memory yet — first run)` when
  the recall is empty / bridge is down.

Trailing instruction given with the dispatch:

> Dispatch sub-agents to do the work, guided by your memory of what has worked
> or failed on this project before. Track them, then report every changed file.

## Output contract — OrchestratorOutput (the REAL shape)

Kaia must reply with ONLY valid JSON of this exact shape — no prose. This is
the pydantic contract in `factory/factory_modules/data_types.py`:

```json
{
  "status": "success",
  "summary": "coordinated scout+builder; reviewer verified",
  "artifacts": ["specs/plan.md"],
  "notes_for_next_agent": "what the reviewer should check",
  "changed_files": ["src/one.ts", "src/two.ts"],
  "commit_message": "implement onboarding flow",
  "subagents": [
    { "file": "scout", "note": "mapped the repo, 12 findings" },
    { "file": "builder", "note": "implemented onboarding; verified files exist" }
  ],
  "used_subagent_tools": true
}
```

Rules the gates enforce (`orchestrator_dispatched`, `diff_matches_claims`):

- `used_subagent_tools` **must be `true`** — Kaia must have actually called
  `subagent_create` / `subagent_continue`. Never claim dispatch she did not do.
- `subagents` **must be non-empty** — name each sub-agent (`file`) and its
  outcome (`note`). This is the traceable proof she coordinated.
- `changed_files` lists ONLY files a sub-agent actually wrote AND that exist on
  disk at report time. Kaia never writes code files herself.
- `status: "fail"` is legal — the reviewer getst it and Kaia revises; the gate
  cares about dispatch proof, not a rosy summary.

## Dispatch chains — routing sub-agents to local / hybrid / online models

Kaia's whole job is dispatching sub-agents. Each dispatch picks a **model** via
`subagent_create(task, thinking, model=…)`. **The standing team definitions
are the file** (the truth, not this table): `factory/factory_factory_config/roster.yaml`
(teams in `stacks:`, agent roles in `role_defaults:`, model catalog in `tiers:`)
resolves to the `factory.*.config.yaml` the run builds, and the
`justfile` is the same surface as shell recipes
(`just orchestrate` / `just sdlc` / `just simple-sdlc`, honoring
`FACTORY_CONFIG` → `FACTORY_ROSTER` → `FACTORY_MODEL_TIER`).

**What pi (Kaia) can actually dispatch — verified in `~/.pi/agent/models.json`
on 2026-08-31** (registry ↓ = the subagent's model must resolve here):

| Chain | Sub-agent model routing (per role) | Verdict |
|---|---|---|
| **local** | planner/orchestrator `lmstudio/qwen3.6-35b-a3b@q2_k_xl` · builder `lmstudio/qwen3.5-9b` · scout `lmstudio/qwen3.5-4b` · reviewer `lmstudio/gemma-4-12b-it@q4_k_m` · UI `lmstudio/frontend-design-expert-8b*` | ✅ in registry + loaded in LM Studio (`*`: not in registry, but LM Studio serves it and it has run) |
| **hybrid** | mix local LM Studio + online `google/*` or `openrouter/*` per role | ✅ hybrid = local ∪ online (pi-reachable) |
| **online** | `google/gemini-3-flash-preview` · `google/gemini-3.1-pro-preview` · `google/gemini-2.5-pro` · `openrouter/meta-llama/llama-3.3-70b-instruct` — API keys present | ✅ pi-reachable (subagent fallback itself names `openrouter/google/gemini-3.5-flash`) |

**opencode-go now pi-reachable via the bridge.** Registered in pi's registry
(`~/.pi/agent/models.json` provider `opencode-go` → `http://127.0.0.1:4603/v1`);
`scripts/opencode-go-bridge.py` (tmux `ogb`) injects `OPENCODE_GO_API_KEY`
from `~/command/.env` and proxies to `https://opencode.ai/zen/go/v1` (bare
model ids, e.g. `deepseek-v4-flash` — strip the `opencode-go/` prefix).
Verified: `pi --model opencode-go/deepseek-v4-flash` answers. The standalone
`opencode/*` free ids (`big-pickle`, `nemotron-3-ultra-free`) remain
opencode-agent-only (`ocrd` profile) — they run when the factory runs under
`coding_agent: opencode`, not as pi subagents.

`thinking` is REQUIRED on every dispatch: `low` simple tasks · `medium` routine ·
`high` complex multi-step · `xhigh` hardest/accuracy-critical. **Omit `model`
to inherit the parent model**; pass it explicitly to build a mixed chain.
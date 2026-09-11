---
name: create-new-teams
description: "Create a new factory team (roster stack) by interviewing the user first. Ask a lot of questions — purpose, local/cloud/hybrid surface, which agents, which model EACH agent runs (orchestrator gets a big model by default), cost/speed/quality trade-offs, kaia tier, and what context to inject — then hand-edit the roster file and validate. Use when the user wants a new team, a new roster, a new configuration of agents+models, or 'make a team for project X'."
version: "1.0"
allowed-tools: read, write, edit, bash, grep, glob
---

# Create New Teams — ask first, then make the team real

## Sibling skills
- **`create-new-agent`** — a single new agent role (do this first if the team
  needs a role that doesn't exist yet).
- **`add-or-edit-ai-models`** — changing models/prompts/injection for an
  existing team or agent.
- **`factory` / `factory-launcher` / `start-the-factory`** — running the team once it
  exists.
- **`command-repo`** — conventions when work lands in `~/command`.

## The one rule
**A team is a `stacks:` block in the roster file: which agents, and which model
each one runs.** The model is a per-(team × agent) assignment — the same agent
role runs a big model in one team and a cheap one in another. Hand-edit the
file; never generate a throwaway config. Source of truth:
`factory/factory_factory_config/roster.yaml` — the ONE file: teams (`stacks:`), agent
roles (`role_defaults:`), and the model catalog (`tiers:`) all live together
after `models.yaml` was merged in (Sep 2026).

## When to use
- User says: "make a new team", "new roster for project X", "I want a team for
  …", "how do I set up agents for this?".

## 0. Interview — ASK THE USER, do not guess

Do not open the file until you have answers. Go one question at a time; write
down the answers. Ask at least these (adapt order to the conversation):

| # | Question | Why it matters |
|---|---|---|
| 1 | **What is the team FOR?** Project/domain, in one sentence. | Defines purpose; may imply a specialized roster (e.g. WayOfTeams wot-*) vs generic SDLC. |
| 2 | **Local, cloud, or hybrid?** Offline/private (LM Studio) vs cloud (opencode: bigger context, needs keys) vs mix (cloud plan/review, local build). | Picks the surface per agent; decides keys needed. |
| 3 | **Full SDLC or specialized?** The 6 (orchestrator, planner, builder, scout, reviewer, documenter) — or a subset/specialists. | Shapes the `agents:` list. |
| 4 | **Which agents exactly?** Name them (existing roles). If one doesn't exist, branch to `create-new-agent` first. | The stack's `agents:` list. |
| 5 | **What model should EACH agent run?** Walk the list: orchestrator = big model (biggest context + strongest reasoning available); planner/reviewer = strong; builder/scout = fast + cheap. Ask per agent: "and for the builder?" | The per-agent model assignment — the heart of the stack. **Never a 4B orchestrator/planner/reviewer.** |
| 6 | **Cost vs speed vs quality?** Cheap & fast (repetition-heavy builders/scouts), or depth (frontier/local-big for the coordinator). | Fine-tunes the picks. |
| 7 | **Kaia tier?** T0 (none), T1 (admission notes, default), T2 (Kaia synthesizes/coordinates). | `kaia_tier` on the stack. |
| 8 | **What should be injected into their context?** AGENTS.md? project skills? knowledge/memory? prior spec? | The `inject:` list (context sources per agent/team). |
| 9 | **Name the team.** | The stack name (`factory run --roster <name>`). |

If the user answers "you pick", default: local surface, full 6, orchestrator on
the largest local model, planner/reviewer mid-strong, builder/scout cheap, T1.
State the defaults back before writing.

## 0. Fast path — let the scaffold write it

`factory team new` emits the exact `stacks:` block you'd hand-write below, validates
agents/tier/models immediately, and refuses a team with no models at all:

```bash
factory team new my-team \
  --agents orchestrator,planner,builder,scout,reviewer,documenter \
  --tier local \
  -m orchestrator=lmstudio/qwen3.6-35b-a3b@q2_k_xl \
  -m builder=lmstudio/qwen3.5-9b \
  --thinking builder=low \
  --inject AGENTS.md \
  --kaia-tier T1
then:
  factory team show my-team     # expanded view: role → model/thinking/tools/writes
  factory doctor                # green = the team would spawn
```
Hand-editing below stays valid and is the same thing — the scaffold just does
the boilerplate + validation and preserves every comment in the file.

## 1. Hand-edit the roster (one file)

Open `factory/factory_factory_config/roster.yaml` and add the stack. Two ways to give the
team its models — pick the one the interview produced:

```yaml
stacks:
  my-team:
    tier: local           # a named model set from the tiers: catalog (same file)
    agents: [orchestrator, planner, builder, scout, reviewer, documenter]
    overrides:            # per-team per-agent tuning; a model here wins over the tier
      orchestrator:
        model: lmstudio/qwen3.6-35b-a3b@q2_k_xl   # big model — the default
      builder:
        model: lmstudio/qwen3.5-9b                # cheap + fast
        thinking: low
    inject:               # context to inject into these agents
      - AGENTS.md
    kaia_tier: T1
```

```yaml
# B) fully explicit — one model per agent, no tier
stacks:
  my-team:
    agents: [orchestrator, planner, builder, scout, reviewer, documenter]
    overrides:
      orchestrator:
        model: lmstudio/qwen3.6-35b-a3b@q2_k_xl
      planner:
        model: lmstudio/qwen3.6-35b-a3b@q2_k_xl
      builder:
        model: lmstudio/qwen3.5-9b
      scout:
        model: lmstudio/qwen3.5-4b
      reviewer:
        model: lmstudio/gemma-4-12b-it@q4_k_m
      documenter:
        model: lmstudio/qwen3.5-9b
    kaia_tier: T1
```

Keep the shape honest: **each role may run a different model; the orchestrator
usually runs a big one.** Never leave a team that silently runs one default
model for everyone — say it explicitly.

## 2. Validate before it runs

```bash
factory doctor          # planned: prompts exist, models resolve, no 4B coordinator
factory rosters         # resolves every stack today — shows per-agent models
```

- Every agent on the `agents:` list must exist in `role_defaults:` and
  have its prompt pair in `factory/factory_data/prompt_engineering/<name>/`.
- Every model must resolve (local → present in `:1234/v1/models`; cloud →
  opencode/pi catalog). A bare `provider/model` is mandatory.
- **`doctor`/validate refuses: orchestrator|planner|reviewer on a 4B model.**

## 3. Prove it spawns (the acceptance bar)

```bash
factory run --roster my-team "<ask>"      # or FACTORY_ROSTER=my-team …
factory team smoke my-team                # planned: cheap run, every lane visible in :4601
```

A new team is not real until **every member appears as a lane in the trace UI**
(:4601) — orchestrator through documenter — and the run reaches green or a
gate with teeth says why not. Report the `factory_id` + what the trace showed.

## Golden rules
1. **Ask before you build.** The interview is the product.
2. **One file is the source of truth** — hand-edit `roster.yaml`; never a
   throwaway config, never a "random tweak".
3. **The orchestrator runs a big model. Never a 4B.**
4. **Per-agent models are the norm**, not a special case.
5. **Validate + smoke before you call it done** — spawning in the UI is the bar.
6. If the team needs a role that doesn't exist → `create-new-agent` first.
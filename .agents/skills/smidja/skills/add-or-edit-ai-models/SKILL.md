---
name: add-or-edit-ai-models
description: "Tune the model (and prompt, and injected context) for agents, by interviewing the user first. Ask a lot of questions — which team(s) and role are affected, what they value (reasoning vs speed vs cost vs context), local/cloud/hybrid surface, exact model id, and whether they also want to tune the prompt or what gets injected — then hand-edit the roster file (+ prompt pair), validate in the catalog, and re-run. Use when the user wants to change an agent's model, add a model, fine-tune prompts, or control what context is injected into agents."
version: "1.0"
allowed-tools: read, write, edit, bash, grep, glob
---

# Add / Edit AI Models — tune model, prompt, and injection, after asking

## Sibling skills
- **`create-new-teams`** / **`create-new-agent`** — creating teams and roles.
- **`smidja` / `smidja-launcher` / `smidja-start`** — running them.
- **`command-repo`** — conventions when work lands in `~/command`.

## When to use
- User says: "change the builder's model", "that agent is too weak/slow",
  "what can run the planner locally?", "give the team more context",
  "the reviewer needs to see the spec" — model, prompt, or injection tuning.

## The three dials (all hand-editable)
1. **Model** — per (team × agent), in the roster file (`stacks` → per-agent
   `models:` / `tiers:` (the model catalog lives in the same file).
2. **Prompt** — `smidja/smidja_data/prompt_engineering/<name>/{system,user}.md`.
   Who the agent is, and the task template.
3. **Injection** — what goes into the agent's context before it works: the
   team's `inject:` list (AGENTS.md, skills, memory, prior spec) and the
   `{{…}}` slots in `user.md`. Tune these to shape what the agent sees.

## 0. Interview — ASK THE USER, do not guess

| # | Question | Why it matters |
|---|---|---|
| 1 | **Which scope?** One team, a few teams, or everywhere (a shared preset/tier)? | Decides where the edit lands: one stack's `models:` vs the shared preset. |
| 2 | **Which role(s)?** orchestrator/planner/builder/scout/reviewer/documenter/… | The per-agent target. |
| 3 | **What is wrong / what do you value?** Speed? Quality/reasoning? Context length? Cost (free?)? Privacy/local? | The selection criteria — the answer changes the pick. |
| 4 | **Local, cloud, or hybrid?** And do we have the surface (VRAM / keys)? | Narrows the catalog. |
| 5 | **Exact model id, or should I pick?** You pick → state candidates + your choice before editing. | The **provider/model-id** to write. |
| 6 | **Prompt too?** Also tune `system.md` (who it is) or `user.md` (task template / what's injected)? | Branches into prompt editing — the triad rule applies. |
| 7 | **Injection?** Which context should it see — AGENTS.md, project skills, knowledge/memory, a prior spec, git log? | Fills the `inject:` list / `user.md` slots. |
| 8 | **Same or different across teams?** Same role, but different model per team? | Per-team assignment semantics. |

If the user says "you pick": keep the role's current class, improve one axis
they named, prefer local where VRAM/keys permit, and say exactly what you chose
and why.

## 0. Fast path — let the scaffold set it

`smidja model set` writes the exact change below (and `model pin <stack> <role>
<model>` is its alias), validates the string against known providers (+ the LM
Studio catalog for `lmstudio/`), and refuses a small model on
orchestrator/planner/reviewer:

```bash
smidja model set cloud-free orchestrator openrouter/qwen3.5-235b-a22b:free   # shared tier
smidja model set local-ui builder lmstudio/frontend-design-expert-8b          # one team (override)
smidja model pin  local-ui builder lmstudio/frontend-design-expert-8b         # alias, stack-forced
smidja doctor --stack local-ui   # green = applied + legal
```
The change below is identical — hand-edit only when the export is the point
(machine-verified either way).

## 1. Change the model (per team × agent)

In `smidja/smidja_smidja_config/roster.yaml`, target the exact scope:

```yaml
# one team only — override just that agent (the runtime resolver reads overrides.<role>.model)
stacks:
  my-team:
    agents: [orchestrator, planner, builder, scout, reviewer, documenter]
    overrides:
      orchestrator:
        model: lmstudio/qwen3.6-35b-a3b@q2_k_xl   # the big one
      builder:
        model: lmstudio/qwen3.5-9b                # cheap + fast
```

```yaml
# every team that uses a preset — edit the shared preset
tiers:                 # the canonical key (was models.yaml tiers:; model_presets: is a resolver alias)
  local:
    builder: lmstudio/qwen3.5-9b          # ← change here = every local team
```

Selection rules (see `plans/model-team-agent-playbook.md` §1):
- **orchestrator/planner/reviewer** → strong reasoning + long context; **never
  4B**. Reviewer default: `gemma-4-12b-it@q4_k_m` ("deep but cheap").
- **builder** → fast/cheap executor (`qwen3.5-9b`, `qwopus3.5-9b-coder`,
  `frontend-design-expert-8b` for UI).
- **scout** → the only 4B slot is fine; 9b for depth.
- Always write `provider/model-id` (a bare id that matches several providers
  raises at validation). Changing an agent's model = fresh session (context
  window does not carry across a model change — intended).

## 2. Validate against the real catalog before re-running

```bash
curl -s http://localhost:1234/v1/models | python3 -c "import json,sys;print('\n'.join(m['id'] for m in json.load(sys.stdin)['data']))"   # local
smidja doctor                    # planned: models resolve, prompts exist, no 4B coordinator
smidja rosters                   # show what each stack resolves to today
```
A local id missing from `:1234` will fail at spawn — catch it here, in a second,
not halfway through a run.

## 3. Tune the prompt (hand-edit)

`system.md` — who the agent is. If the `purpose` changes, edit the role entry
AND the system `Purpose` in the same edit (they must not drift).

`user.md` — the task template. The injection slots you can shape:
- `{{prompt}}` — the incoming ask (never edit this).
- `{{previous_envelope}}` — prior agent's typed output (cross-team context).
- `{{context_handoff_dir}}` — files other agents left for it.
- Anything else the agent must always see → add to the team's `inject:` list or
  append to the template.

**Triad rule:** prompt changes that touch the output contract must stay in sync
with `data_types.py` and the call site's `output_type=` — one edit, three files.

## 4. Tune injection (what the system feeds the agent)

The `stacks:` `inject:` list and per-agent `user.md` control what context enters
the window:
```yaml
stacks:
  my-team:
    inject:
      - AGENTS.md                       # project rules the builder must follow
      - smidja/smidja_data/knowledge/team-notes.md   # domain memory
```
Keep injection lean — every injected file spends the agent's context window on
setup instead of work. When in doubt, smaller + focused beats bigger + diffuse.

## 5. Re-run and confirm

```bash
smidja run --roster my-team "<ask>"
```
Check the trace (:4601): the changed lane shows the new model, and the
injected context shows up in the agent's transcript. Report what changed and
what the run showed.

## Golden rules
1. **Ask before you edit.** Scope (which team/role), the axis (speed/quality/
   context/cost), the surface (local/cloud), and exact id come from the user.
2. **Per-team model is the default** — same role can differ across teams.
3. **Never a 4B orchestrator/planner/reviewer** — `doctor` enforces it.
4. **Validate in the catalog first** — a typo catches you in a second, not in
   a run.
5. **Prompt + output type + call site are one thing** (triad) — change all three.
6. **Injection is a budget** — lean and focused, and visible in the transcript.
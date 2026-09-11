---
name: create-new-agent
description: "Create a new agent role by interviewing the user first. Ask a lot of questions — the job/purpose, which existing role to clone from, which model it runs, thinking level, tools and write boundary, lane color, which teams should contain it, and what context/prompt to give it — then hand-edit the roster file and the prompt pair, and validate. Use when the user wants a new agent, a new role, a specialist ('make me a devops agent'), or an agent for a team that doesn't exist yet."
version: "1.0"
allowed-tools: read, write, edit, bash, grep, glob
---

# Create New Agents — ask first, then make the role real

## Sibling skills
- **`create-new-teams`** — teams (stacks) built from agent roles.
- **`add-or-edit-ai-models`** — tuning an existing agent's model/prompt/injection.
- **`factory` / `factory-launcher` / `start-the-factory`** — running the team.
- **`command-repo`** — conventions when work lands in `~/command`.

## The one mental model
**An agent is a role, defined once; it carries no model of its own.** A role =
one `role_defaults:` entry (purpose, thinking, tools, writes, color) +
one prompt pair (`factory/factory_data/prompt_engineering/<name>/{system,user}.md`).
The model is assigned later, per team, in the stack. So creating an agent is
creating the *role* — and every team that lists it gets a model for it.

## When to use
- User says: "make an agent for…", "we need a spec agent", "add a devops role",
  "create a specialist like the wot-* ones".

## 0. Interview — ASK THE USER, do not guess

Go one question at a time. Minimum set:

| # | Question | Why it matters |
|---|---|---|
| 1 | **What is this agent FOR?** The job, in one sentence — its `purpose`. | Fills `purpose`; must match the system prompt. |
| 2 | **A brand-new role or a clone?** Any existing role to start from (planner/builder/scout/reviewer/documenter/orchestrator…)? | `--from <role>` seeds tools/writes/prompt pair. |
| 3 | **Does it write, or is it read-only?** Changes in the repo vs reports only (`writes: []`). | Sets the `writes` boundary — the enforcement rule. |
| 4 | **Which tools does it need?** read/bash/edit/write; grep/find/ls for search; `subagent_*` if it spawns subagents. | The `tools` allowlist (and the extension-tools-must-be-named rule). |
| 5 | **How much thinking?** low (mechanical recon) / medium (executor) / high (judgement: coordinator, planner, reviewer). | Sets `thinking`. |
| 6 | **Which model should it run?** Across which teams? Remind: this is per-team, decided in the stack — but ask what class of model it needs (big/strong context vs cheap/fast). | Feeds the model assignment. **Never 4B if it's an orchestrator/planner/reviewer.** |
| 7 | **Which teams should contain it?** List stacks, or "later". | Registers it in stacks now or leaves it available. |
| 8 | **What context should be injected?** AGENTS.md? domain skills? memory? prior envelope? | The prompt injection plan. |
| 9 | **Lane color?** (optional — the UI swatch). | `color` hex; default from palette. |

The user may answer "you pick": clone `planner` for a specialist, medium
thinking, read+write as appropriate, cheap model, add to the current team.
State your choices before writing.

## 0. Fast path — let the scaffold write it

`factory agent new` appends the `role_defaults:` entry below, scaffolds the prompt
pair, assigns a lane color, and refuses a bad name up front:

```bash
factory agent new my-role --from planner \
  --thinking medium --tools read,edit,write,bash,grep,find,ls \
  --writes specs/ \
  --purpose "<one sentence from the interview>"
then:  factory doctor    # green = roles known, prompts on disk
```
Hand-editing below stays valid — the scaffold writes the same block + prompt
pair, and preserves every comment in the file.

## 1. Hand-edit the role (roster file)

Add the role to the `role_defaults:` block in `factory/factory_factory_config/roster.yaml`:

```yaml
role_defaults:
  my-role:
    thinking: medium            # off|minimal|low|medium|high|xhigh|max
    purpose: <one sentence from the interview>
    tools: [read, bash, edit, write, grep, find, ls]   # or the list from Q4
    writes: [specs/]            # [] = read-only; omit = any (minus protected)
    color: "#22d3ee"            # optional lane swatch
```

Rules (origin `references/config.md`):
- **tools** is an allowlist; omitted = all builtins. `grep/find/ls` are off in
  bare pi — name them. If the role spawns subagents, add `subagent_*` tool names
  **and** `harness_engineering: [factory/factory_data/harness_engineering/subagents.ts]`.
- **writes** is the repo boundary enforced after every call: trailing `/` =
  dir prefix, `*` one segment, `**` crosses, else exact path. `data_dir`
  (reports/sessions) is always writable.
- **thinking** is inert on non-reasoning models — set it anyway (portable).

## 2. Write the prompt pair (hand-editable, tunable — the point)

Create `factory/factory_data/prompt_engineering/<name>/system.md` and `user.md`:

- `system.md` — who the agent is; repeat `purpose` verbatim (they must not
  drift); its output contract.
- `user.md` — the task template: `{{prompt}}`, `{{previous_envelope}}`,
  `{{context_handoff_dir}}`, ends with a `## Report` JSON example. Anything else
  the agent needs injected (AGENTS.md, skills, examples) can be appended here or
  wired through the team's `inject:` list.

**Triad rule:** the output *type* (`factory/factory_modules/data_types.py`), the
`## Report` example (`user.md`), and `output_type=` at the factory call site are one
thing — change one, change all three in the same edit.

Clone path shortcut: copying `planner`'s pair and editing the Purpose/Report
sections is the fastest correct start.

## 3. Register it

- Add the name to the `agents:` list of any stack that should contain it
  (then give it a model there — per team).
- If an factory should use it directly, list it in that factory's `REQUIRED_AGENTS` /
  phase `owner=` (factory name agents, never models).

## 4. Validate

```bash
factory doctor          # planned: role exists, prompts present, model resolvable, no 4B coordinator
```
A role with no prompt pair or an unresolvable model fails before anything
spawns — that's the design, not a bug.

## Golden rules
1. **Ask before you build.** The interview is the product.
2. **An agent = role (no model) + prompt pair.** Models are per-team.
3. **Prompt pair is hand-editable and tunable** — keep system `purpose` and
   `user.md` `## Report` in sync with the output type (triad rule).
4. **tools = capability, writes = boundary.** State both honestly.
5. **A 4B role must never be orchestrator/planner/reviewer.**
6. Validate before you trust it; add it to a team + smoke to see it live.
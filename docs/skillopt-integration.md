# SkillOpt in Ymir — training agent skills through trajectory-driven optimization

> **Purpose:** integrate SkillOpt (https://github.com/zerwiz/SkillOpt)
> into Ymir so the system's agent skills, Smíðja prompts, and Eindri
> dispatch templates improve over time through validation-gated editing
> rather than manual iteration.
>
> SkillOpt treats a skill document as the trainable state of a frozen
> agent: a separate optimizer model turns scored rollouts into bounded
> add/delete/replace edits; a candidate edit is accepted only when it
> strictly improves a held-out validation score. The deployed artifact is
> a compact `best_skill.md` that runs against the unchanged target model.

---

## What SkillOpt brings to Ymir

| Capability | Ymir today | With SkillOpt |
|---|---|---|
| Skill refinement | Manual edit of `.agents/skills/*/SKILL.md` | Trajectory-driven edits validated against a held-out gate |
| Prompt tuning | `add-or-edit-ai-models` (interactive, manual) | Automated rollout → reflect → select → update loop |
| Recurring-task optimization | Dispatched identically each time | Replayed, scored, and improved each epoch |
| Cross-model transfer | Not tracked | `best_skill.md` transfers across model scales & harnesses |
| Nightly self-evolution | None | SkillOpt-Sleep reviews sessions, consolidates validated skills |

---

## Integration points

### 1. Skill document optimization — the primary path

Every Ymir skill (`.agents/skills/<name>/SKILL.md`) is a natural-language
skill document — exactly what SkillOpt optimizes. The loop:

```bash
pip install skillopt

# 1. Register a skill document for training
skillopt register .agents/skills/galdr-ymirsystem/SKILL.md --name galdr --model opencode-go/deepseek-v4-flash

# 2. Run training epochs against a benchmark or real-task trajectory
skillopt train --skill galdr --epochs 5 --val-size 5

# 3. Deploy the optimized artifact
skillopt deploy --skill galdr --out .agents/skills/galdr-ymirsystem/best_skill.md
```

The optimizer edits the skill document (add/delete/replace passages), scores
each edit by running the target model against a task set, and keeps only
edits that strictly improve validation scores. No model weights change —
the deployment artifact is pure text.

**Which skills to optimize first** (ordered by expected ROI):

1. **Smidja factory skills** — `smidja-instructions`, `smidja-start`,
   `create-new-agent`, `create-new-teams` (high task volume, well-defined
   success criteria).
2. **Eindri dispatch templates** — the prompts given to dispatched workers.
3. **Galdr skills** — `galdr`, `tyr-check` (compliance tasks with pass/fail
   gates = natural validation signal).

### 2. Smíðja prompt optimization — direct mapping

Smíðja's `system.md` and `user.md` files (per agent role in the roster)
are the same text-space artifacts SkillOpt is designed to optimize. The
`add-or-edit-ai-models` skill today does interactive, manual tuning.
SkillOpt replaces that with an automated loop:

```bash
# Train Smíðja's builder prompt against real sdlc/scout trajectories
skillopt train \
  --prompt smidja/smidja_data/prompt_engineering/builder/system.md \
  --trajectory-dir smidja/smidja_data/sessions/ \
  --task-type sdlc \
  --val-gate "phase_status == 'passed' and accepted == true" \
  --epochs 10

# Deploy the optimized prompt back
skillopt deploy --prompt smidja/smidja_data/prompt_engineering/builder/system.md \
  --out smidja/smidja_data/prompt_engineering/best_system.md
```

**Trajectory source:** Smíðja's SQLite trace (`smidja/smidja_data/smidja.db`)
provides `sessions`, `phases`, and `events` tables — each completed run is a
scored trajectory the optimizer can replay.

### 3. Eindri dispatch instruction optimization

When Ymir dispatches an Eindri worker (via `bin/einherjar-spawn.sh`), it
passes task instructions and context. These templates can be optimized:

- Harvest past dispatch trajectories from the observer log and Smidja trace.
- Train an optimizer on the instruction template.
- Validate: did the dispatched worker complete the task? (acceptance signal
  from Smíðja gates).
- Deploy improved instruction templates to the dispatch config.

### 4. SkillOpt-Sleep — nightly self-evolution (secondary path)

SkillOpt v0.2.0 ships **SkillOpt-Sleep** (`skillopt-sleep` CLI): a nightly
offline engine that harvests sessions, mines recurring patterns, replays
them, and consolidates validated skills behind a held-out gate.

```bash
pip install skillopt-sleep

# Run overnight — reads session history, produces best_skill.md updates
skillopt-sleep --session-dir ~/.yggdrasil/sessions/ --output best_skills/
```

**Integration with Ymir:** schedule via Nornir (cron) at 00:30 (after the
daily briefing has been written and sessions logged):

```yaml
# config/cron.yaml (add alongside existing jobs)
- time: "00:30"
  job: bin/nornir-job-skillopt-sleep.sh
  description: "SkillOpt overnight self-evolution — harvest sessions, mine skills"
```

The script:
1. Reads the day's Smíðja trace from `smidja/smidja_data/smidja.db`.
2. Runs `skillopt-sleep` against registered skills/prompts.
3. Writes accepted `best_skill.md` artifacts to a staging dir.
4. Diffs against current skill documents; reports changes to Runes (audit).
5. **Does not auto-apply** — Allfather reviews before merge (human-in-the-loop law).

### 5. Harness integration — adapter needed for OpenCode

SkillOpt v0.2.0 ships integration shells for **Claude Code**, **Codex**,
**Copilot**, and **Devin**. Ymir's primary harness is **OpenCode** — this
is the gap to fill.

The integration is a small plugin that:
1. At session start, loads the trained `best_skill.md` into the session
   context (paralleling how `.opencode/plugins/saga-sessionstart.js`
   injects the Sága digest).
2. At turn end, sends the turn trajectory to SkillOpt-Sleep's harvest
   buffer (if enabled).

```js
// .opencode/plugins/skillopt-loader.js (sketch)
export const SkilloptLoader = async ({ client, directory }) => {
  return {
    session: async ({ session }) => {
      const bestSkill = await readFile(`${directory}/.agents/skills/best_skill.md`);
      if (bestSkill) {
        client.session.promptAsync({
          path: { id: session.id },
          body: { parts: [{ type: "text", text: bestSkill }] },
        });
      }
    },
  };
};
```

See `.agents/skills/galdr-ymirsystem/assets/harness-integration/opencode.md` for
the plugin contract and hook surface.

---

## Data flow

```
┌──────────────────────────────────────────────────────────────┐
│                    Ymir Session                              │
│  Allfather dispatches task → Brokk → Eindri worker           │
│  Smíðja traces every phase into SQLite                       │
└──────────────────┬───────────────────────────────────────────┘
                   │ trajectory (scored rollout)
                   ▼
┌──────────────────────────────────────────────────────────────┐
│               Gunnlöð Training Loop                          │
│                                                              │
│  Rollout → Score → Reflect (optimizer edits skill doc)       │
│  → Aggregate → Select (accept if val improves) → Update      │
│  → Evaluate (held-out gate)                                  │
│                                                              │
│  Output: best_skill.md (300–2000 tokens)                     │
└──────────────────┬───────────────────────────────────────────┘
                   │ best_skill.md
                   ▼
┌──────────────────────────────────────────────────────────────┐
│               Deployment                                     │
│                                                              │
│  ┌─ Smíðja prompt (system.md / user.md) → auto-injected     │
│  ├─ Skill .agents/skills/*/best_skill.md → loaded by hook    │
│  ├─ Eindri dispatch template → improved instructions          │
│  └─ OpenCode plugin loads best_skill.md at session start      │
└──────────────────────────────────────────────────────────────┘
```

---

## Directory layout

```
ymir/
├── .agents/skills/
│   └── <name>/SKILL.md          ← source skill documents (input)
│   └── <name>/best_skill.md     ← trained artifacts (staged, not applied)
├── .agents/skills/gunnlod/       ← Gunnlöð skill (if adopted as internal skill)
├── smidja/smidja_data/
│   ├── smidja.db                ← trajectory database (training data, read-only)
│   └── prompt_engineering/      ← system.md/user.md (trainable prompts)
│       └── <role>/               ← per-role prompt files
│           └── best_system.md   ← trained prompt (staged)
├── .opencode/plugins/
│   └── skillopt-loader.js       ← OpenCode Gunnlöð integration (planned)
├── bin/
│   ├── skillopt-setup.sh        ← one-time SkillOpt installation
│   └── nornir-job-skillopt-sleep.sh  ← nightly cron wrapper (00:30)
├── .venv/                        ← SkillOpt installation (pip install skillopt)
└── docs/
    └── skillopt-integration.md  ← this document
```

---

## Installation

Prerequisites: Python 3.13+, uv (or pip with venv).

```bash
# 1. Create venv
uv venv .venv

# 2. Install
uv pip install --python .venv/bin/python skillopt skillopt-sleep

# 3. Verify
.venv/bin/skillopt-sleep --help
.venv/bin/skillopt-train --help
.venv/bin/skillopt-eval --help
```

One-time setup (also available as `bin/skillopt-setup.sh --dry-run` to preview):

```bash
bin/skillopt-setup.sh
```

Register Ymir's highest-ROI skills for the first training cycle:

```bash
.venv/bin/skillopt register .agents/skills/smidja-instructions/SKILL.md --name smidja-instructions
.venv/bin/skillopt register .agents/skills/smidja-start/SKILL.md --name smidja-start
.venv/bin/skillopt register .agents/skills/galdr-ymirsystem/SKILL.md --name galdr
```

First training run (requires API keys in `config/agents.yaml` or `.env.local`):

```bash
.venv/bin/skillopt-train \
  --config configs/galdr.yaml \
  --backend openai_chat \
  --target_model opencode-go/deepseek-v4-flash \
  --optimizer_model opencode-go/deepseek-v4-flash \
  --num_epochs 5 \
  --out_root .agents/skills/galdr-ymirsystem/
```

Nightly cron: `00:30 bin/nornir-job-skillopt-sleep.sh`.

Deployed `best_skill.md` artifacts live in staging — the Allfather reviews before adopt. Never auto-apply.

## Naming — Gunnlöð

Gunnlöð guards the mead of poetry in Norse myth — knowledge
distilled through cycles and gated before access. The mead was
created from the wisest being's blood, fermented over three nights
(training epochs), and held behind her gate (validation). The result
was the most potent form of wisdom, potent despite small quantity
(300–2,000 tokens of best_skill.md).

That is SkillOpt's function in Ymir: raw session trajectories are
the raw material, training epochs are the fermentation, the held-out
validation gate is Gunnlöð's gate, and the `best_skill.md` artifact
is the mead — potent, compact, distilled wisdom.

Gunnlöð sits beside Gungnir in the platform map:

| Subsystem | Norse | Role |
|---|---|---|
| Skill synthesis | **Gungnir** | creates new skills from scratch |
| Skill optimization | **Gunnlöð** | refines existing skills from trajectories |

Gunnlöð is also listed in `.agents/skills/galdr-ymirsystem/assets/registry.md`
(under external tools — it is adopted OSS, installed via pip) and in
`README.md` (System Map, Skills, gratitude). MIT attribution lives in
`NOTICE`.

---

## Relationship to existing capabilities

| Existing | How Gunnlöð (SkillOpt) relates |
|---|---|
| `add-or-edit-ai-models` (smidja-factory skill) | Gunnlöð automates the *prompt tuning* dial of that skill — same target, but trajectory-driven instead of interview-driven. Both coexist: use `add-or-edit-ai-models` for one-off model/prompt changes, Gunnlöð for continuous optimization from real trajectories. |
| Gungnir (skill synthesis) | Gungnir *creates* new skills from scratch. Gunnlöð *improves* existing ones. Different phases of the same lifecycle. |
| Smíðja trace (SQLite) | Gunnlöð consumes Smíðja's trace as training trajectories. Read-only access — never writes to the trace DB. |
| Sýn (watch/supervision) | Gunnlöð-Sleep runs under Nornir (00:30), after Sýn has guarded the turn end for the day. No overlap. |
| Mímir / Mimirsbrunn | Memory well stores episodes and embeddings. Gunnlöð stores trained `best_skill.md` artifacts. Complementary — neither replaces the other. |

---

## Open questions for the Allfather

1. **Which skills get the first training cycle?** Smidja factory skills
   have the highest task volume and clearest validation gates. Start there.
2. **Should Gunnlöð-Sleep be opt-in or default?** It writes only to
   staging dirs (never auto-applies), so the cost is low. But it does read
   all session data — privacy posture needs to be declared.
3. **OpenCode integration priority:** SkillOpt ships Claude Code / Codex
   adapters but not OpenCode. Is the `.opencode/plugins/skillopt-loader.js`
   adapter a priority, or hold until more harnesses are in use?
4. **Model for the optimizer:** SkillOpt needs a separate optimizer model
   (different from the target model). Local or cloud? This is a config
   decision in `config/agents.yaml` (e.g., a strong reasoning model for
   editing, while workers run cheaper models).

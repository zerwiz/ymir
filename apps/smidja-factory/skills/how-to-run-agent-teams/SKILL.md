---
name: how-to-run-agent-teams
description: Run a FULL agent team with the smithy — Kaia (orchestrator) plus every role on the same model roster, chained through orchestrate. Use when the user wants to "send the team", "run everyone on <model>", "kaia should be that and everyone", or "make a workflow/chain to test a full team". Covers the nemotron-team mode (all agents + Kaia on Nemotron 3 Ultra Free via pi), the no-flash rule for Kaia, and project-anchoring with SMIDJA_PROJECT_DIR. Pairs with smidja-start / smidja-launcher (launch&watch) and smidja (internals).
argument-hint: "[launch a team | nemotron-team | run everyone on a model | ...]"
---

# How to run agent teams (the smithy)

A **team run** = a roster (which agents) × a chain (what they execute). The
full-team play is **`orchestrate`**: Kaia is the `orchestrator` — she receives
the WHOLE task first, dispatches sub-agents (scout → planner → builder →
reviewer) via her `subagent_*` tools, tracks them, and reports every changed
file. Do not pass the engineer's prompt straight to one builder; going through
Kaia first is the point (she recalls project memory and plans the dispatch).

This skill is the playbook for "send the team". For single-line launches and
watching, load `smidja-launcher`; for picking teams/models `smidja-start`;
for writing a crisp ask `smidja-instructions`; for the pipeline internals
`smidja`. All smidja work is launched detached and observed — never implement
in the team's place.

## The one command

```bash
cd /home/<user>/CodeP/<project> && \
SMIDJA_PROJECT_DIR=/home/<user>/CodeP/<project> \
  $YMIR_ROOT/scripts/smidja run --mode nemotron-team <ask-path-or-string>
```

That runs the full 6-agent team (orchestrator/Kaia, planner, builder, scout,
reviewer, documenter) — every one on **Nemotron 3 Ultra Free via pi**
(`openrouter/nvidia/nemotron-3-ultra-550b-a55b:free`, 1M ctx), chained through
`orchestrate`. Watch it with `smidja tail <smidja_id>` / `just ui`, audit with
`smidja audit <smidja_id>`.

## Rosters / modes relevant to a full team

| Roster / mode | Agents | Surface | Chain | Use |
|---|---|---|---|---|
| `nemotron` | all 6 on Nemotron | opencode/ocrd | simple-sdlc | test roster, ocrd CLI |
| `nemotron-pi` | all 6 on Nemotron | **pi** (`openrouter/…:free`) | simple-sdlc | same model via pi — thinking visible |
| `nemotron-team` | all 6 on Nemotron | **pi** | **orchestrate** | THE full-team mode — Kaia dispatches everyone |
| `cloud-reasoning` | cloud reasoning team | opencode | simple-sdlc | hard/long tasks |
| `orchestrate` | orchestrator+reviewer | cloud-fast | orchestrate | Kaia dispatches (default roster) |

`smidja modes` lists all 13 modes; `smidja rosters` resolves each stack and shows
the surface per agent (a `✓ pi` column means it runs through the pi harness).

## Golden rules (hard-won — breaking these caused real failures)

1. **Kaia runs on the SAME model as the team — never flash.** Admission,
   `smidja kaia`, and recovery default to `KAIA_CONFIG=smidja.cloud-fast`
   (**deepseek-v4-flash**). A nemotron run MUST override it, or the admission
   one-shot silently talks to flash while everyone else is on nemotron:
   `nemotron*` modes now set `KAIA_CONFIG=smidja.nemotron-pi` automatically, so
   only a stray `smidja kaia`/`smidja admit` elsewhere can drift — check with
   `smidja kaia --memory` and the run's `kaia_notes.md`. The admission session id
   is recorded in `session/kaia_admit.log` / `kaia_handoff.json`; verify its
   `agent_map.json` model is nemotron, not `-flash`.

2. **Anchor the run to the PROJECT repo with `SMIDJA_PROJECT_DIR`.** `smidja`
   `cd`s to its own ROOT before launching, so cwd-based project detection
   (git toplevel) fails — a wayoffactoy ask launched from anywhere lands in
   `~/Ymir`'s data dir and agents work on the wrong repo. Always set
   `SMIDJA_PROJECT_DIR=/home/<user>/CodeP/<project>` so sessions, the trace db,
   and gates all live in the project (e.g. `…/wayoffactoy/smidja/smidja_data/`).
   Confirm with the header of `session/*/raw_output.jsonl` — `"cwd"` must be
   the project, and `kaia_handoff.json`'s `repo_root` must be the project.

3. **The project repo must have the smidja's support dirs.** Modules import
   from the smidja ROOT, but prompts/extensions resolve from the project cwd:
   `smidja/smidja_data/prompt_engineering/` and `smidja/smidja_data/harness_engineering/`
   must exist in the project. If missing, symlink them from `~/Ymir`:
   `ln -s $YMIR_ROOT/smidja/smidja_data/{prompt_engineering,harness_engineering} smidja/smidja_data/`.

4. **Thinking is only visible on the pi surface.** The opencode CLI
   (`--format json`) does NOT stream reasoning/text parts into the NDJSON —
   template streams show only step/tool events, so a phase reads "no thinking
   text in the recorded stream". Nemotron via **pi** records
   `content[].thinking` blocks (scan: `session/<agent>/pi_sessions/*.jsonl`).
   For "see the team think", use `nemotron-pi` / `nemotron-team`, not `nemotron`.

5. **Free-tier caveats.** Nemotron 3 Ultra Free via ocrd can 404 mid-run
   (a fallback-on-fallback has no retry → phase fails). OpenRouter's
   `…:550b-a55b:free` through pi is steadier and shows thinking. If a free run
   dies, audit, don't relaunch blindly — it's usually the provider, not the ask.

## How the team works (so you can report to the user)

- `smidja/smidja_orchestrate.py` — chain: `request` (engineer) → `orchestrate`
  (Kaia owns the whole task, MUST use `subagent_*` — gate
  `orchestrator_dispatched`) → `review_N` (reviewer) → maybe `revise_N`
  (Kaia closes findings), bounded by `MAX_REVISION_LOOPS`.
- Every agent call streams events (tool_call, compact, thinking, model_error)
  into the project's `smidja/smidja_data/smidja.db` (WAL — reads never block).
- `smidja stop <smidja_id>` kills a misbehaving team (children first);
  `scripts/smidja-emergency-stop.sh` is the persistent kill-switch.

## Verify a team run landed correctly

```bash
smidja sessions | grep <smidja_id>            # status
smidja phases <smidja_id>                     # per-phase status
smidja tail <smidja_id>                       # live event tail
python3 -c "import json;print([l for l in open('<proj>/smidja/smidja_data/sessions/<id>/agent_map.json')])"   # models pinned
grep '"cwd"' <proj>/smidja/smidja_data/sessions/<id>/*/raw_output.jsonl        # right repo?
cat <proj>/smidja/smidja_data/sessions/<id>/kaia_notes.md                      # Kaia admission notes
```

## Cross-references

- Launch/watch/audit: `smidja-launcher` (`scripts/smidja`, `justfile`)
- Picking teams/models + chain pick: `smidja-start` (`START_SMIDJA.md`)
- Writing the ask file: `smidja-instructions`
- Pipeline internals / smidja / configs: `smidja`
- Roster/model definitions: `smidja/smidja_smidja_config/{roster,models}.yaml`
- Nemotron fallback + surfaces: `START_SMIDJA.md` → "online models fallback"
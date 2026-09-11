---
name: factory-launcher
description: Start and use the software factory from one command — converge the environment, run any chain or mode, watch, audit, stop, talk to Kaia, run bench missions. Use when the user wants to run the factory, scout/sdlc/simple-sdlc/orchestrate work, audit a run, stop a misbehaving agent, check Kaia's memory, or bench local/cloud models. Pair with start-the-factory (how to pick teams/models) and factory-instructions (how to write the ask).
allowed-tools: read, write, edit, bash, grep, glob
---

# factory-launcher — the one command for the factory

`scripts/factory` is the single entry point for any agent (opencode, claude, pi,
herdr, human) to start, watch, audit, and mission the Super Simple Software
Factory. You never do factory work yourself — you launch and observe.

## Sibling skills — load one if the task matches

- **`start-the-factory`** — exactly how to start agents for work: which team
  (roster), local/online/hybrid models, chains, orchestrator, **gotchas**
  (incl. detached-launch rule below).
- **`factory-instructions`** — turn a fuzzy ask into a request file first.
- **`factory`** — internals: cookbooks for install/create/update factory + configs.
- **`command-repo`** — conventions when working inside `~/command`.

Deep-reference docs for the factory live in **`docs/command docs/`**:
`software-factory.md` (overview), `software-factory-run.md` (how to run),
`software-factory-pi.md` / `software-factory-opencode.md` (coding-agent
setups), `software-factory-visualizer.md` (the trace UI this launcher starts),
`FactoryAgentsAndModels.md` (roster + model backends source of truth).

## The command

```bash
scripts/factory up                         # converge env (LM Studio + visualizer + tunnel)
scripts/factory run <chain> "<ask>"        # prompt|scout|plan|plan-build|build-review|orchestrate|sdlc|simple-sdlc
scripts/factory run --mode <name> "<ask>"  # mode = roster + chain preset
scripts/factory run --service <name> "<ask>" # one pick = provider × agent × chain
scripts/factory services                    # list the 9 whole-stack presets
scripts/factory sessions [N]               # last N runs
scripts/factory phases <factory_id>
scripts/factory tail <factory_id>
scripts/factory procs <factory_id>
scripts/factory stop <factory_id>              # kill children-first (misbehaving agents)
scripts/factory pause <factory_id>             # hold a run (SIGSTOP agents) so you can steer
scripts/factory resume <factory_id>            # continue a paused run
scripts/factory steer <factory_id> "msg"       # inject engineer guidance into a running session
scripts/factory admit <factory_id>            # refresh handoff + re-ask Kaia for admission notes
scripts/factory recover <factory_id>          # watchdog ticket → Kaia's ONE recovery decision (prints apply cmd)
scripts/factory watch                     # watchdog loop in tmux (auto-started by factory up)
scripts/factory emergency-stop            # circuit breaker: kill-switch + kill-9 a runaway factory
scripts/factory audit <factory_id>             # gates + tool-call evidence per agent
scripts/factory diagnose <factory_id>          # WHY it failed + the fix to apply (self-improving)
scripts/factory learn <factory_id>             # write the audit+diagnosis into Kaia's memory
scripts/factory kaia "<msg>"               # talk to Kaia (traced, memory-backed)
scripts/factory memory <project>           # what Kaia has learned for a project
scripts/factory mission <T1|T2> [--config <roster>]   # bench a model, then audit+learn
scripts/factory modes                      # list the 12 execution modes
scripts/factory rosters                    # list + validate rosters/models
scripts/factory team list|new|show|smoke  # make a team (stacks: block in roster.yaml)
scripts/factory model set|pin             # change a model (stack override or shared tier)
scripts/factory doctor [--stack <name>]   # spawn-readiness check — must be green
```

Run from the repo root (`~/command/`). Everything is idempotent; reads never
block a running run (WAL db).

The files that define what this launcher runs:

- `factory/factory_factory_config/roster.yaml` — the ONE file: teams (named stacks of
  agents with their models/tools/writes; `--roster <name>` / `FACTORY_ROSTER=<name>`
  pick one), agent roles (`role_defaults:`), and the model catalog (`tiers:` —
  every role × backend tier: local · local-agile · local-max · local-ui · cloud ·
  cloud-free · cloud-reasoning · hybrid-plan-local · hybrid-build-local · review).
  Swap surface: `--model`, `FACTORY_<ROLE>_MODEL`, `FACTORY_MODEL_TIER`.
- **Nemotron 3 Ultra Free is the always-available primary fallback** — `nemotron`
  and `nemotron-pi` rosters/modes (plus `nemotron-team`: the full team on
  Nemotron via **pi** with Kaia orchestrating), and an automatic one-retry
  fallback whenever an agent's model fails to resolve or produces no output
  (surface-aware: `FACTORY_FALLBACK_MODEL_PI` / `FACTORY_FALLBACK_MODEL_OPENCODE`).
  Missions default to the `nemotron` roster (`FACTORY_MISSION_CONFIG` to bench a
  different team).
- `justfile` — the `just` recipes (same engine): `just scout/sdlc/simple-sdlc/`
  `orchestrate` to launch chains, `just sessions/phases/tail` to watch; it
  honors the same `FACTORY_CONFIG` / `FACTORY_ROSTER` / `FACTORY_MODEL_TIER` order.

## Rules

1. **Converge first.** `factory run` runs `factory up` first — it reloads a
   not-loaded LM Studio model with a tiny completion, so a run never starts on
   a half-warm environment. If `up` refuses, fix the warnings, don't run anyway.
2. **Never do the work yourself.** Launch the chain and watch it. The factory's
   agents own the implementation; you own launching, observing, and reporting.
3. **Stop, don't wait.** An agent that misbehaves or a run that hangs is a
   `factory stop <factory_id>` (or the UI Stop button). Children die first, the trace
   finalizes as `fail`.
4. **Audit before believing.** `factory audit` shows tool-call evidence per agent.
   Zero tool calls on a claimed build = hallucinated completion. When a run
   fails, `factory diagnose <factory_id>` tells you WHY and the exact fix to apply
   (stronger model, prompt hardening, redundant commit, stopped run). Then
   `factory learn` writes that outcome + diagnosis into Kaia's engram memory so
   she recalls it and picks better next time — the self-improving loop.
5. **Launch detached for anything that may outlive a tool-call timeout.** A
   35B planner needs minutes per phase. Launching `factory run` through a short
   tool-call timeout SIGKILLs the subagents mid-generation (LM Studio:
   "Client disconnected") and the run finalizes `fail` with **no** error events
   — audit of `sdlc-4027` / `sdlc-4271` (2026-08-31). For long runs:
   ```bash
   tmux new-session -d -s ssf \
     "FACTORY_PROJECT_DIR=<target-repo> /home/zerwiz/command/scripts/factory run sdlc '<ask>'"
   # then watch with read-only calls:  factory sessions / factory tail <id>
   ```
6. **Cloud models are three.** deepseek-v4-flash (workhorse), big-pickle,
   nemotron-3-ultra-free — under the `ocrd` opencode profile. Local models
   (LM Studio, `lmstudio/*`) need no keys; local-model reliability evidence
   lives in `tests/local-models/RESULTS.md` (JSON-discipline and read-only
   reviewer gotchas).
7. **Runaway? Emergency-stop, not stop.** A recursive/admission loop or
   dozens of procs is a `scripts/factory emergency-stop` (writes a
   `.factory-emergency` kill-switch — blocks auto-admission — kills every
   factory pattern, marks in-flight runs `aborted`). Resume after fixing:
   `scripts/factory up` clears the kill-switch. Infra (LM Studio / ogb / viz) is
   never touched.

## Modes (roster + chain presets)

`recon` · `local-fast` · `local-planner` · `local-max` · `cloud-free` ·
`cloud-fast` · `cloud-reasoning` · `hybrid-plan-local` · `hybrid-build-local` ·
`review-gate` · `orchestrate` (Kaia dispatches sub-agents).

Pick the mode that fits the work kind; `factory run --mode <name> "<ask>"` sets
roster + chain for you. `--model <provider/model>` overrides the model for one
run; the `tiers:` catalog in `factory/factory_factory_config/roster.yaml` is the standing
swap surface.

## Services (whole-stack presets)

`factory run --service <name> "<ask>"` picks **everything at once** — the provider
every model runs on, the coding agent (pi | opencode), and the factory chain:

`local` · `local-planner` · `cloud` · `cloud-free` · `cloud-reasoning` ·
`hybrid-plan-local` · `hybrid-build-local` · `review` · `orchestrate`.

Any part can be overridden with `--config` / `--chain` / `--model` /
`--profile`. `factory services` lists all nine with their roster/chain/model.

## Observing

- `factory sessions` → recent runs. `factory phases <id>` → phase statuses.
- Visualizer: `factory ui` (tmux) → `http://localhost:4601` (sessions + `#/memory`
  for Kaia's engram UI), API on `:4600`.

## Learn / memory

- `factory learn <factory_id>` — the launcher writes objective audit fields
  (outcome, gates, tool calls) into `factory/factory_data/kaia.engram`.
- `factory memory <project>` — hybrid-recall what worked for that project.
- Kaia reads this before dispatching, so she biases toward what passed there
  before instead of starting cold.
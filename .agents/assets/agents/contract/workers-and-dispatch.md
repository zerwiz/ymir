Read when: sending out a worker, deciding what the counsellor does itself, steering or answering an agent, running untrusted code, or reporting to the helm.

# Workers, dispatch and the agents' roads

Part of the Ymir contract. The prior text is kept verbatim in `docs/contract-history/AGENTS-2026-11-24.md`.

## The mandate

You are the Allfather's **counsellor and helper**, covering **Development**, **Marketing**, **Business Strategy** and
**Life Execution**: one operator, never zero direct address in an answer to him. You stay in the **main hall**: you plan, steer, advise,
review, and **send out Eindri to do the work**. Complex, isolated or parallel forging is done by **Eindri**, workers
spawned inside Utgard containers on Yggdrasil worktrees, never by you alone in the main tree. You receive their
harvest, review it, and weave it into the hall.

| Who | Does |
|---|---|
| the Allfather | the single operator; never zero direct address in an answer to him; a turn an agent or a script began is answered to that sender |
| the counsellor (the role Brokk names; the seat carries its own name) | stays in the main hall; plans, steers, reviews, dispatches; does not build alone what a worker can forge in isolation |
| Eindri | the doers: isolated smiths in Utgard on Yggdrasil worktrees; the specialists are Sindri, Bragi and Huginn |

## Dispatch first

- The counsellor stays in **main**; it does not descend into the forge alone where an Eindri can turn it.
- An errand goes out as an **Eindri** on a Yggdrasil worktree (gate: `bin/agents/einherjar-spawn.sh` /
  `bin/agents/eindri-start.sh`) when it is complex, isolated or parallel. The brief carries the area, the skill and the
  deliverable path, and is spoken in the house voice.
- The counsellor receives, reviews and sews. Findings and reports land in the hall; the Allfather alone seals merges
  (RULES/08).
- Anything plan-sized is written first (plans live in the hoard); nothing heavy is improvised directly in main.

## Workers are Eindri; a harness never spawns its own subagents (RULES/49)

The Allfather's word, 2026-11-10: *"Claude Code never spawns its own subagents — workers are Eindri."*

Every worker in this house is an **Eindri**, sent out through `bin/agents/eindri-start.sh` (or
`bin/agents/agent-run.sh <figure> "<task>"`), seated on a Yggdrasil worktree, armed, and in Utgard when the work is
untrusted. A harness's private subagent has none of those: no worktree, no sandbox, no Rune, no seat the Allfather can
find. So no harness may spawn one.

For Claude Code the refusal is mechanical, in every project: `.claude/hooks/eindri-only.sh` is a user-scope
`PreToolUse` hook on `Agent|Task`. It denies the spawn and names the Eindri road. `bin/seat/harness-extensions-install.sh`
seats it; the install runs that installer, Gróa's update re-verifies it, and Eir's `claudehooks` surface fails when it is
stale. A worker that cannot reach the Eindri road does the task inline, or asks the Allfather, never a shadow worker.
The full law is `RULES/49-workers-are-eindri.md`, cross-referenced from `RULES/02-agents.md`.

## Isolation and sandbox

| Id | Rule |
|---|---|
| ygg1 | Never edit files directly in the main tree for complex tasks. |
| ygg2 | Always create an isolated `.yggdrasil/<agent-id>/` worktree. |
| ygg3 | Parallel agents each get their own worktree. |
| ygg4 | Merge explicitly after completion, then clean up. |
| utg1 | Untrusted code, dynamic skills and sub-agent tasks run inside Utgard. |
| utg2 | Utgard enforces CPU, RAM and timeout caps. |
| utg3 | Utgard has no host root and no network by default. |
| utg4 | A failed Utgard execution never touches main (law 6: fail safely). |

## Talking to and steering an agent

- **One road (2026-11-21).** Every message from one agent to another, on any machine, goes through
  `bin/fleet/fleet-tell.sh` (the Pi and MCP tool `gna_fleet_tell`). Its targets are a machine (its arm holder), an
  errand, `machine:errand`, a pane, or `machine:pane`, and `--all` for every arm holder. It carries the steer verbs:
  `--steer`, `--answer` (answer a worker's question) and `--stop` (stop at a safe point). The `steer` action of
  `ymir_errand` calls it too. It signs each line, uses the target machine's own `bin/agents/tell.sh` over ssh, falls
  back to typing into the agent's herdr pane, and reports one row per target. Do not ssh or type into a pane by hand for
  this. The page is `docs/features/fleet-tell.md`.
- **A brief goes into a worker's pane** with `bin/agents/eindri-send.sh [--from "<you>"] <pane> "<text>"`. Every line
  carries a `[from …]` stamp; only `[from the operator …]` is the operator's own word.
- **A report goes to the helm through its wake queue** (plan 369 item 8): `bin/voice/rodd-arm.sh tell --from
  "agent <errand>" "<line>"`, or `bin/agents/answer.sh <errand>` when the errand recorded the `arm:` return address.
  Never type a report into the helm's pane; its input box is often in use.
- **The Veil (plan 350 B, 2026-11-22).** At the Allfather's word: *"An arm holder must always reassure that he will get
  the work done — received — so he can know what's going on and if it was a correct build."*
  - A done needs evidence: a worker's terminal act carries one `--evidence "<command>"` per claim. With none, a failing
    one, or red PR checks, the errand ends `unproven`, is not reviewed, and the holder is told.
  - The holder answers every report: `bin/agents/veil.sh received <id>` within 2 minutes, then `accepted <id>` or
    `rework <id> "<why>"`. `bin/agents/veil.sh pending` lists what waits. An unanswered report is typed into the pane
    after 2 minutes and turns the trouble panel's `receipts` row red after 10.
  - Steer with an id: `bin/agents/veil.sh steer --to <pane|errand|hermes:<session>> "<line>"`; the agent answers
    `received <id>`. The how-to is `docs/features/the-veil.md`.

## Agent-to-agent: Ratatoskr (A2A 1.0)

- Agent-to-agent and cross-realm collaboration runs on the open **A2A 1.0** protocol (JSON-RPC 2.0 over HTTPS, task
  lifecycle, SSE streaming). Every agent publishes an **Agent Card** (`/.well-known/agent-card.json`), scoped per realm
  (Svartalfaheim); discovery is capability-based.
- Redis pub/sub is the queue under the A2A task model (A2A = semantics, Redis = throughput). Messages follow
  `.agents/bus/protocol.ts`, and `.agents/bus/` is still a stub. Every A2A message is observed into **Mimirsbrunn** and
  logged to **Runes**.
- **What stands (corrected 2026-09-30):** `packages/a2a/ratatoskr/` (the shared contract at
  `packages/contracts/src/agent-card.ts`, `A2A_PROTOCOL = "a2a/1.0"`) runs as the heart's node on **`<heart>:8301`**.
  The heart's name is read from the fleet registry in the home, never written here (plan 278). Measured:
  `GET http://127.0.0.1:8301/.well-known/agent-card.json` returns its card with `streaming: true` and the skill
  `well-recall`. An external `a2abridge` runs **seat-side** (`:7777`) as the adapter a harness talks to; it is not the
  backbone, and no `a2abridge` binary exists on the server.
- The directory of many installs and per-pair grants does not exist yet: that is plan **61**
  (`$YMIR_HOME/svartalfaheim/whynotproductions/projects/ymir/plans/61-the-constellation-many-ymirs-one-forge.md`). Way of
  Teams (`~/CodeP/wayofteams`) remains the sold control plane; Ymir's daemon works standalone.
- Völundr orchestrates: it dispatches Eindri as A2A tasks, recalls memory before dispatch, honours the
  anti-hallucination gate, and reaches tools through MCP.

## The smithy (Smíðja)

The smithy's books are the specification for how a run is launched, what a team is (`roster.yaml`, teams in
`stacks:`), how the prompt is written and what an install needs: **read the book before the code** (`RULES/36-the-run-is-visible.md`). The
smithy now lives in its own repo, **`zerwiz/smidja`**, with its whole history, and installs into
`~/.local/share/ymir-apps/smidja/` through `bin/apps/apps.sh install smidja`. Its books (`cookbooks/`, `skills/`, once
`apps/smidja-factory/cookbooks/` and `apps/smidja-factory/skills/` in this tree, with the skill at
`.agents/skills/smidja-factory/` and its visualizer at `.agents/skills/smidja-factory/apps/visualizer`) and its governing rules travel with it;
on a seat they are on the harness-wide skill shelf (`~/.pi/agent/skills/smidja-factory`). `smidja` (and `scripts/smidja`
here) is its one command, and the Smíðja MCP drives it from every harness; only pi works inside a run.

## Hermes, an adopted worker runtime

**Hermes**, the Nous Research agent runtime (`hermes-agent.nousresearch.com`,
`github.com/NousResearch/hermes-agent`, MIT), is an adopted worker runtime with its own brain, memory, skills and
isolated subagents. `bin/engine/hermes-ensure.sh` provisions it for any user who lacks it (the `hermes` step of
`bin/engine/ymir-install.sh`). Config and identity stay the user's own; Ymir only guarantees the runtime exists.

## Skill synthesis (Gungnir) and open source first

- A missing capability may be synthesized into a new skill under `.agents/skills/`. Every synthesized skill must be
  validated inside Utgard before production use and registered in the skill index (law 7: script first; recurring tasks
  become reusable skills). Galdr governance: `.agents/skills/galdr-ymirsystem/SKILL.md`.
- Ymir **owns three things**: the UI/UX (Hlidskjalf), the agent runtime (Brokk/Eindri/Völundr) and A2A collaboration
  (Ratatoskr). Every other feature adopts a validated OSS project first (engram/mimirsbrunn, Redis, Traefik/Caddy,
  OAuth2-proxy, cloudflared, MinIO/FileBrowser, PM2/Docker, MCP servers, `smidja`, `a2aproject/a2a`) behind a Norse-named
  shell (law 8). Never rebuild a subsystem that already exists on the machine.
- **Þjazi:** sub-agents in terminal panes use the Þjazi backend (protocol 14+). Presentation spaces require Þjazi
  0.8.0+; opt out with `config/herdr-presentation-spaces`.

## CHANGE LOG

- **2026-11-25** — written when the contract was split by topic (plan 369 item 7); its text is folded from the
  sections of the prior `AGENTS.md`, kept verbatim in `docs/contract-history/AGENTS-2026-11-24.md`.

---
name: hamr
description: >-
  Agent-only reference for Brokk harness operations.
  Use before spawning or recovering a Eindri or Eindri-home, handling a trust dialog, sending a harness-specific skill invocation, interrupting or exiting an agent, resuming an exited agent, or verifying a new harness adapter.
  Contains verified facts for claude, codex, opencode, pi, pi-signed, grok, kimi, cursor, and muse.
user-invocable: false
metadata:
  internal: true
---

# hamr — harness adapters — per-harness reference

This is the one skill, trigger, and routing owner for harness-specific Brokk operations.
Load this router first, then exactly the common reference and one harness reference selected below.
When an action spans rows, load the union once rather than every reference.
Files under `references/` are resources of this skill, not additional catalogued skills.

## Path contract

The skill directory is the directory containing this `SKILL.md`.
Resolve on-demand reference links and relative links to their executable, documentation, or sibling-skill owners against the skill directory, including links named by a nested reference.
Operational paths keep the context named by their owner: `config/` and active-home settings belong to the active Brokk home, `state/` belongs to that home, and project settings such as `.claude/settings.json` belong to the target project.

## Non-negotiable safety

Never dispatch a Eindri or Eindri-home on an unverified adapter.
If `config/crew-harness` or `config/Eindri-home-harness` names one, tell the Allfather under `../../../AGENTS.md` section 9 that the requested worker runtime is not verified, use Brokk's own verified runtime for current work, and ask only whether to verify the requested runtime for future work.
Do not pause current work for that choice.

On `unknown`, ask the Allfather instead of guessing.
A current Allfather override beats detection, while a per-task override governs only that dispatch.
For recovery and control, use the exact `harness=` in `state/<id>.meta`; never infer it from a model or provider.

Deliver lifecycle actions only through `../../../bin/brokk-control.sh <task-id> interrupt|exit|relaunch`.
Never type an interrupt key or exit command through `brokk-send`, where routing-marked lifecycle text becomes chat.
Trust handling is complete only when inspection proves the target started processing its instructions; delivery success alone is not proof.
Muse is verified only for Eindri and scout work, never a Eindri-home or primary.

## Detection

`../../../bin/hamr-harness.sh` prints Brokk's own harness from verified environment markers, then process ancestry.
Only `BROKK_PI_HARNESS=pi-signed` at the launch boundary together with `PI_CODING_AGENT=true` selects Pi-signed; shared unmarked launcher ancestry remains Pi.
`../../../bin/einherjar-spawn.sh` owns worker marker establishment, while the README launch command owns the signed-primary boundary.
`../../../bin/hamr-harness.sh crew` resolves `config/crew-harness`, where absent or `default` means Brokk's own harness.
`../../../bin/hamr-harness.sh Eindri-home` resolves `config/Eindri-home-harness` -> `config/crew-harness` -> Brokk's own harness.
`../../../bin/einherjar-spawn.sh` re-resolves on every spawn, and an explicit per-spawn argument wins for that spawn.
A new adapter's verified marker and command name must land in `../../../bin/hamr-harness.sh`.

## Operation-to-reference matrix

Every emitted plan appends the selected or recorded harness reference after the named common references.
The `harness-adapter-routing-v1` object is the machine-readable and human-visible selection contract: choose the operation, choose the scenario within it, then append the selected harness reference.
`default` is the normal scenario when no narrower scenario applies.
Kimi establishes its unsupported primary boundary in its selected harness reference; Muse follows Non-negotiable safety above.
A new tool remains undispatchable until the `verify` plan, its harness entry, every named owner, and the live checks land.

```json harness-adapter-routing-v1
{
  "operations": {
    "start": {
      "default": ["references/common/dispatch.md", "references/common/model-and-effort.md"],
      "trust-dialog": ["references/common/control-and-recovery.md"]
    },
    "trust": {"default": ["references/common/control-and-recovery.md"]},
    "skill": {"default": ["references/common/control-and-recovery.md"]},
    "interrupt": {"default": ["references/common/control-and-recovery.md"]},
    "exit": {"default": ["references/common/control-and-recovery.md"]},
    "resume": {"default": ["references/common/control-and-recovery.md"]},
    "recovery": {
      "default": ["references/common/control-and-recovery.md"],
      "replacement-profile": ["references/common/control-and-recovery.md", "references/common/dispatch.md", "references/common/model-and-effort.md"],
      "Eindri-home": ["references/common/control-and-recovery.md", "references/common/primary-hooks.md"],
      "replacement-Eindri-home": ["references/common/control-and-recovery.md", "references/common/dispatch.md", "references/common/model-and-effort.md", "references/common/primary-hooks.md"]
    },
    "primary": {"default": ["references/common/primary-hooks.md"]},
    "model-effort": {
      "default": ["references/common/model-and-effort.md"],
      "configured-profile": ["references/common/model-and-effort.md", "references/common/dispatch.md"]
    },
    "verify": {"default": ["references/common/dispatch.md", "references/common/control-and-recovery.md", "references/common/primary-hooks.md", "references/common/model-and-effort.md"]}
  },
  "harnesses": {
    "claude": "references/harness/claude.md",
    "codex": "references/harness/codex.md",
    "opencode": "references/harness/opencode.md",
    "pi": "references/harness/pi.md",
    "pi-signed": "references/harness/pi.md",
    "grok": "references/harness/grok.md",
    "kimi": "references/harness/kimi.md",
    "cursor": "references/harness/cursor.md",
    "muse": "references/harness/muse.md"
  }
}
```

## Organisation law (RULES/) — domains, houses, agents

Hamr binds the harnesses; the house law governs *who* they run. The source of
truth is `RULES/`:

- **A house is a company** — and only that. **WayOf** is the house.
- **A domain is a field of knowledge — a *Grein* (pl. *Greinar*).** The eight:
  `ymirlabs` (the system itself) · `brokkforge` (engineering) · `runestone`
  (records/compliance) · `muninn` (memory) · `dvalin` (crafted tools) ·
  `utgard` (creative) · `askr` (human products) · `mannheim` (holding).
- **Eindri are the specialists** (marketer, builder, researcher, planner,
  reviewer, documenter, scout, …); each names its **domain** and its **craft**.

**Agent binding (Rule 02) — Hamr's own concern:**

- Canonical profiles live **only** in `.agents/agents/*.md`.
- Every harness directory is a **symlink** to them — never a copy:
  - OpenCode: `.opencode/agent/<name>.md` → `../../.agents/agents/<profile>.md`
  - Pi: `.pi/agents/<profile>.md` → the same canonical files
- Never edit `.opencode/agent/` or `.pi/agents/`; edit `.agents/agents/<profile>.md`
  and run `bin/valknut-load.sh --all` to rebind. `bin/hamr-harness.sh` only
  *detects* the harness shape; it never writes agents.
- **No mock agents:** ids, names, domains, models, and status are real and
  sourced. The demo roster is the single, labelled mock (demo mode only).

In the code the eight are `DOMAINS` (`DomainId`/`DomainDef`) and an agent carries
`domain` (not `house`) — see `src/data/realms.ts` and `AgentCard`.

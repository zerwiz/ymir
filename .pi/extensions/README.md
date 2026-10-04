# Pi extensions — Brokk distro runtime

These extensions make a Pi session open as **Brokk** the way Ymir intends: the
primary takes the high seat automatically, the Sága session-start context is
injected before the first turn, and supervision stays alive across the session.
Ported from the validated upstream agent-distro reference for
[plan 29](../../docs/plans/29-brokk-distro-runtime.md).

## This tree is NOT the extension home

**Every file here is a no-op that registers nothing, and that is deliberate.**
The real extensions live in **`.pi/shared/extensions/`** and are deployed by copy
to **`~/.pi/agent/extensions/`**.

Pi loads both this project directory and the global one, and it does **not**
de-duplicate. An extension present in both registers its tools twice and pi exits
with a tool-name conflict, so **no agent can be seated**. A file exporting no
factory at all is an error in its own right. So this tree holds exactly two things:

| File | What it is |
|---|---|
| `*.ts` — nine of them | **no-op factories.** Each header says why. They register nothing and exist only so a duplicate cannot collide |
| `lib/` | **helper modules, not extensions.** Pi does not recurse past one level and a subdirectory loads only with an `index.ts`, so `lib/` is never scanned. The deployed extensions reach these by relative import, and `bin/seat/valknut-load.sh --pi` copies them alongside |

**Two homes, and one of them is wrong:**

| Path | Holds |
|---|---|
| `.pi/shared/extensions/` | **every extension** — the source of truth |
| `~/.pi/agent/extensions/` | the deployed copy the running harness loads |
| `.pi/extensions/lib/` | helper modules. **A leftover.** Plan 29 built them in this flat tree; the single-home migration moved the extensions and not their internals, so the loader grew a second copy line to cover the gap |

`bin/seat/valknut-load.sh --check` (added 2026-10-04) fails if the deployed tree drifts
from source, if a test file is in the live tree, or if anything in this directory
registers a tool.

## The extensions themselves

| File | Norse role | Purpose |
|---|---|---|
| `syn-turnend-guard.ts` | **Sýn** (watchful sight) | inject the Sága digest at session start, re-emit on compaction, refuse a blind turn end, PreToolUse seatbelts |
| `gna-pi-watch.ts` | **Gná** (Frigg's messenger) | watcher continuity: arm, re-arm, deliver actionable wakes; emits the Skuld dispatch offer |
| `ro.ts` | **Ró** (calm/peace) | calm presentation: hides transcript chrome, replaces the working row with a longship, `/ro` toggle |
| `skuld-branch-supervision.ts` | **Skuld** (the Norn of what shall be) | supervision branch: handles routine wakes with a cheaper model; `/skuld-model` |
| `lib/vordr-sessionstart-supervisor.mjs` | **Vörðr** (warden) | supervise the digest child process |
| `lib/rodd-operational-input.ts` | **Rödd** (voice) | structured operational-message wire bridge |
| `lib/ro-*.ts` | **Ró** helpers | visibility, assistant/user layout adapters, working longship |
| `lib/skuld-branch-*.ts` | **Skuld** helpers | dispatch handshake + model picker |
| `lib/ymir-home.ts` | deploy plumbing | resolve the distro root the loader recorded (`.ymir-root`) — a deployed copy cannot find its own `bin/` by walking up from `~/.pi` |

*All of the above paths are in `.pi/shared/extensions/`, except the `lib/` entries.*

## Wiring

- **Sága** digest: `bin/time/saga-session-start.sh`, routed by `bin/time/saga-sessionstart-run.sh`.
- **Gná** watcher: `bin/syn-watch-arm.sh`; turn-end check: `bin/syn-turnend-guard.sh`.
- **Gleipnir** lock: `bin/gleipnir-lock-lib.sh` (writes `state/.lock`).
- **Root record:** `~/.pi/agent/extensions/.ymir-root`, written by `bin/seat/valknut-load.sh --pi`
  and read by `lib/ymir-home.ts` — the deployed extensions live outside this tree, so
  the loader has to tell them where `bin/` is.
- **Rödd** wire: `bin/rodd-operational-input.sh`.

The harness passes `BROKK_SESSION_PID` so the session lock is bound to the live
Pi process, not the short-lived digest helper.

## Other harnesses

OpenCode, Claude Code, Codex, and Cursor adapters are wired too; see
`docs/plans/29-brokk-distro-runtime.md` §7 and
`.agents/skills/galdr-ymirsystem/assets/harness-integration/`. Grok is not yet implemented.

## Agents

Agents live in `.agents/agents/` and are bound per tool by `bin/seat/valknut-load.sh`
(OpenCode reads `.opencode/agents/`; Pi links resolve under `.pi/agents/`).

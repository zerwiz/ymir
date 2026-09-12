# Pi extensions — Brokk distro runtime

These extensions make a Pi session open as **Brokk** the way Ymir intends: the
primary takes the high seat automatically, the Sága session-start context is
injected before the first turn, and supervision stays alive across the session.
Ported from the validated upstream agent-distro reference for
[plan 29](../../docs/plans/29-brokk-distro-runtime.md).

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

## Wiring

- **Sága** digest: `bin/saga-session-start.sh`, routed by `bin/saga-sessionstart-run.sh`.
- **Gná** watcher: `bin/syn-watch-arm.sh`; turn-end check: `bin/syn-turnend-guard.sh`.
- **Gleipnir** lock: `bin/gleipnir-lock-lib.sh` (writes `state/.lock`).
- **Rödd** wire: `bin/rodd-operational-input.sh`.

The harness passes `BROKK_SESSION_PID` so the session lock is bound to the live
Pi process, not the short-lived digest helper.

## Other harnesses

OpenCode, Claude Code, Codex, and Cursor adapters are wired too; see
`docs/plans/29-brokk-distro-runtime.md` §7 and
`.agents/skills/galdr-cli/assets/harness-integration/`. Grok is not yet implemented.

## Agents

Agents live in `.agents/agents/` and are bound per tool by `bin/valknut-load.sh`
(OpenCode reads `.opencode/agent/`; Pi links resolve under `.pi/agents/`).

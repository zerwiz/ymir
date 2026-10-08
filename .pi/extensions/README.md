# Pi extensions — the Brokk distro runtime, ONE home

These extensions make a Pi session open as **Brokk** the way Ymir intends: the
primary takes the high seat automatically, the Sága session-start context is
injected before the first turn, and supervision stays alive across the session.
Ported from the validated upstream agent-distro reference for
[plan 29](../../docs/plans/29-brokk-distro-runtime.md).

## This tree IS the home (one home, 2026-10-04)

Pi auto-discovers **two** extension locations and does **not** de-duplicate:
`.pi/extensions/` (project) and `~/.pi/agent/extensions/` (global). An extension
present in both registers its tools twice, pi exits with
`Tool "…" conflicts with …`, and **no agent can be seated**.

So the extensions live in exactly one tree — this one — and **nothing is
deployed** to the global home. Commit `ac5fd8ad` (2026-10-04) moved the last
files out of `.pi/shared/extensions/` and removed that tree.

| Path | What it is |
|---|---|
| `.pi/extensions/*.ts` | single-file extensions — the source of truth |
| `.pi/extensions/<name>/` | a multi-file extension, with an `index.ts` pi loads (pi does not recurse past one level) |
| `.pi/extensions/lib/` | helper modules the extensions import. Pi never scans a bare `lib/`, so it is not an extension |
| `~/.pi/agent/extensions/.ymir-root` | **only** a root record (not an extension), written by `bin/seat/valknut-load.sh --pi` |

`bin/seat/valknut-load.sh --check` fails if any extension also stands in the
global home, or if the root record is absent. `bin/seat/valknut-load.sh --pi`
removes any global duplicate and writes the record.

**Root resolution (Rule 12 — walk, never count).** An extension locates the repo
that owns `bin/` through the `.ymir-root` record (`.pi/extensions/lib/ymir-home.ts`)
and a walk up to the tree owning `.pi/` and `RULES/`. `.pi/shared/extensions/` and
the old "project tree holds no-op stubs, global tree holds the real files" design
are **retired**.

## The extensions themselves

| File | Norse role | Purpose |
|---|---|---|
| `syn-turnend-guard.ts` | **Sýn** (watchful sight) | inject the Sága digest at session start, re-emit on compaction, refuse a blind turn end, PreToolUse seatbelts |
| `gna-pi-watch.ts` | **Gná** (Frigg's messenger) | watcher continuity: arm, re-arm, deliver actionable wakes; emits the Skuld dispatch offer |
| `skuld-branch-supervision/index.ts` | **Skuld** (the Norn of what shall be) | supervision branch: handles routine wakes with a cheaper model; `/skuld-model` |
| `ymir-well.ts` | **Mimirsbrunn** (the well) | `well_recall` / `well_observe` over the `:4602` bridge |
| `ymirhome.ts` | the ymirhome door | the door into `$YMIR_HOME` |
| `ymir-subagents.ts` | the Eindri roster | exposes every `.agents/agents/*.md` figure through a `subagent` tool |
| `todo.ts` | — | the todo surface |
| `open-editor.ts` | — | `/edit [path]` and `ctrl+shift+e` — open files in the operator's editor |
| `elder.ts`, `eir.ts`, `groa`-door, `rules.ts` | the records council | plan ledger, diagnostics, self-update, house law as a surface |
| `constellation/index.ts` | the mesh | peer discovery over the A2A directory |
| `managandr.ts`, `odrerir.ts`, `opendesign.ts`, `herdr*.ts` | the hall | calendar, the Óðrerir boards, design, pane state |
| `lib/*` | helpers | `rodd-operational-input` (voice wire), `skuld-branch-*`, `ro-*`, `ymir-home`, `vordr-sessionstart-supervisor` |

## Wiring

- **Sága** digest: `bin/time/saga-session-start.sh`, routed by `bin/time/saga-sessionstart-run.sh`.
- **Gná** watcher: `bin/pi/syn-watch-arm.sh`; turn-end check: `bin/gates/guards/syn-turnend-guard.sh`.
- **Gleipnir** lock: `bin/vault/gleipnir-lock-lib.sh` (writes `state/.lock`).
- **Root record:** `~/.pi/agent/extensions/.ymir-root`, written by `bin/seat/valknut-load.sh --pi`
  and read by `.pi/extensions/lib/ymir-home.ts` — the extensions read the tree the loader recorded.
- **Rödd** wire: `bin/agents/rodd-operational-input.sh`.

The harness passes `BROKK_SESSION_PID` so the session lock is bound to the live
Pi process, not the short-lived digest helper.

## Other harnesses

OpenCode, Claude Code, Codex, and Cursor adapters are wired too; see
`docs/plans/29-brokk-distro-runtime.md` §7 and
`.agents/skills/galdr-ymirsystem/assets/harness-integration/`. Grok is not yet implemented.

## Agents

Agents live in `.agents/agents/` and are bound per tool by `bin/seat/valknut-load.sh`
(OpenCode reads `.opencode/agents/`; Pi links resolve under `.pi/agents/`).

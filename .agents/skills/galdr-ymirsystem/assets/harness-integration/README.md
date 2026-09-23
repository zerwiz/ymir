# Harness Integration — the Ymir harness adapter matrix and adapter contract

> **Purpose:** Define how each agent harness (OpenCode, Pi, Claude Code, Cursor, Codex, Grok) seats **Brokk** before the first turn, arms **Sýn** supervision, guards the turn end, and enforces the PreToolUse seatbelts — and give a step-by-step recipe to add a new harness.

This is the reference an agent reads to add a harness adapter or rebuild one from scratch. It is paired with one deep-dive file per harness:

| Deep dive | Harness |
|---|---|
| [`opencode.md`](opencode.md) | OpenCode (Öppencode) |
| [`pi.md`](pi.md) | Pi (`@earendil-works/pi-coding-agent`) |
| [`claude-code.md`](claude-code.md) | Claude Code |
| [`cursor.md`](cursor.md) | Cursor |
| [`codex.md`](codex.md) | Codex |
| *(none — not implemented)* | Grok |

Runtime inventory that every adapter calls: [`../runtime-components.md`](../runtime-components.md).
The governing plan is [`docs/plans/29-brokk-distro-runtime.md`](../../../../../docs/plans/29-brokk-distro-runtime.md) (referred to below as **plan 29**), whose §12 carries the Norse naming law.

---

## 1. What a harness adapter is

> **MCP scope (well · mesh · Teams · Anchor).** `bin/a2a-mcp.sh install` wires the
> `engram` (memory well) and `a2abridge` (A2A mesh) MCP servers into OpenCode's
> repo `opencode.json` **and** Pi. The **Teams** plane (`wayofteams`) and
> **Anchor** memory are **remote** MCP servers named by URL: set
> `WAYOFTEAMS_MCP_URL` / `ANCHOR_MCP_URL` in the private platform env, then run
> `bin/a2a-mcp.sh install`. OpenCode speaks `type: remote` natively; Pi has no
> remote transport, so it reaches them through the `mcp-remote` stdio bridge. The
> URLs never enter the tracked tree. By default the Pi side writes the **global**
> `~/.pi/agent/mcp.json`; `bin/a2a-mcp.sh install --project` writes the repo's
> `.pi/mcp.json` instead, leaving a Pi used elsewhere untouched (launch with
> `pi --mcp-config .pi/mcp.json`). Prefer `--project` when integrating Ymir into
> an existing workflow. `bin/a2a-mcp.sh show` reports what is **actually** wired —
> every key present, not a fixed list.


The Ymir runtime is a **distro**: a directory of instructions, skills, tooling and conventions that turns a general-purpose agent into a specialized one. Launching a supported harness inside `BROKK_HOME` is supposed to instantiate **Brokk** and address the operator as the **Allfather** *before the model's first turn*.

A harness will not do that on its own. Each harness exposes a different set of lifecycle hooks, and each adapter is a thin, harness-specific shim that binds those hooks to **harness-agnostic runtime scripts** in `bin/`. The shim never re-implements runtime logic: it only decides *when* to call a script and *how* to deliver the result.

```
 harness lifecycle event  ──►  adapter shim  ──►  bin/<owner script>  ──►  state/ data/
 (session open / idle /          (.opencode,        (Sága, Sýn, Rödd,
  turn end / tool call)           .pi, hooks.json)   Gleipnir, ...)
```

Every adapter must satisfy the **four-part adapter contract** (§3). A harness with no adapter is *unverified* and must never be used for a dispatched Eindri (`bin/einherjar-spawn.sh` fails closed).

---

## 2. Run-tier vs nudge-tier

The tier answers **how the session-start digest reaches model context**.

| Tier | Meaning | Contract |
|---|---|---|
| **run-tier** | The harness's session-open adapter can **execute** a command and inject its stdout into model context (or as the session's first context) before the model acts. | Adapter calls `bin/saga-sessionstart-run.sh`; the digest text is delivered natively. Nothing is left to the model's discretion. |
| **nudge-tier** | The harness can only post a message into the session and **ask** the model to take the helm. The model can defer. | Adapter calls `bin/saga-sessionstart-run.sh` (which emits the digest *or* a one-line "run `bin/saga-session-start.sh` now" instruction) and delivers it as a prompt/follow-up. |

Important nuance: **tier is per-event, not per-harness.** All current harnesses are run-tier for the session-open digest *except* the disabled/Grok path. But `bin/saga-sessionstart-run.sh` deliberately emits a **nudge** for context-preserving opens (`resume`, `reload`, `fork`) even on a run-tier harness, because re-running the whole digest is redundant when prior context is restored:

```bash
# bin/saga-sessionstart-run.sh:70-72
resume|reload|fork)
  printf 'Run `%s` exactly once now, before executing any other instructions.\n' "bash $SCRIPT_DIR/saga-session-start.sh"
  ;;
```

So the digest is *run* on `startup`/`new`, *re-emitted* on `clear`/`compact` after a completed startup, and *nudged* on `resume`/`reload`/`fork`.

### Tier + mechanism per harness

| Harness | Tier | Session-open mechanism | Source value(s) seen |
|---|---|---|---|
| OpenCode | run (nudge delivery) | plugin `session.created` runs `saga-sessionstart-run.sh`, injects stdout through `client.session.promptAsync` | (wrapper chooses from no payload) |
| Pi | run | extension `before_agent_start` returns a `syn-sessionstart-nudge` message built from the wrapper | `startup`, `clear`, `resume`, `fork`, `compact` |
| Claude Code | run | `SessionStart` hook stdout is injected; wrapper reads `source` from the hook JSON on stdin | `startup`, `resume`, `clear`, `compact` |
| Cursor | run | `sessionStart` hook returns JSON `{"additional_context": "..."}` | `--source startup` (explicit) |
| Codex | run | `SessionStart` hook pipes the JSON payload into `saga-sessionstart-run.sh` | parsed from payload |
| Grok | nudge (upstream only) | upstream uses `.grok/hooks/*sessionstart-nudge.json` | — (not implemented in Ymir) |

---

## 3. The adapter contract (four required parts + one optional)

Every production adapter implements the same four responsibilities. The harness-specific *how* lives in the deep-dive files; the *what* is fixed here.

### Part 1 — Session-open injection

Bind the harness's "session is opening" event to `bin/saga-sessionstart-run.sh`.

```bash
# The one command every session-open adapter invokes.
"$BROKK_ROOT/bin/saga-sessionstart-run.sh" [--source <src>] [--pi-prerequisite]
```

- `--source` ∈ `startup|new|clear|compact|resume|reload|fork`; absent → parse a Claude/Codex-shaped JSON hook payload on stdin, default `startup`.
- `--pi-prerequisite` is Pi-only: an intentional stand-down exits **3** so Pi provider preflight can tell it apart from an eligible attempt that produced nothing.
- **Every ordinary transport path exits 0.** A failed session start must reach the agent as digest text it can act on, never as a refusal to open the session. (Claude `SessionStart` exit 2 blocks initialization.)
- The script records `state/.session-start-complete` so `clear`/`compact` can re-emit instead of re-running.

### Part 2 — Watch arm (Sýn supervision)

Bind a "session is idle / turn ended" event to arm **one** `bin/syn-watch-arm.sh` cycle, and let the adapter own **continuity** (re-arming) so no model tokens are spent on ordinary re-arms.

```bash
bin/syn-watch-arm.sh --restart
```

The arm script polls `state/` every `BROKK_WATCH_POLL_SECONDS` (default 5), writes `state/.watch.heartbeat`, and exits with an actionable line when the wake queue or a `*.signal`/`*.check`/`.watcher-stop` appears:

```
signal: wake queue
signal: <name>
check: <name>
stale: watcher stopped by operator
```

It refuses to arm with exit 0 and a `watcher: read-only - the session helm is held by
another live session` message **only** when a genuinely live other session holds the helm.
A **vacant** helm — no owner, a dead/zombie/recycled owner, or a truncated/empty
lock — is entered in place: the arm script runs `gleipnir_lock_acquire` (which
refuses only a verifiably live owner), and the Pi extension classifies an empty
lock as `missing` so `gna_watch_arm`'s reclaim takes it directly. A vacant helm
is never punted to a manual session start; only a real live contender is refused.

- **Pi** owns continuity in `gna-pi-watch.ts` (Gná); the model gets a **tool** `gna_watch_arm` and a command `/gna-watch-arm` for the first cycle or a repair, never for ordinary re-arms. Gná's liveness is **zombie-aware**: `kill(pid, 0)` alone passes a zombie and a recycled pid, so the watcher reads `/proc/<pid>/stat` — the state character (Z/X = dead) and the starttime recorded at lock acquire (field 22; a mismatch means the kernel handed the pid to an unrelated process) — answers every ordinary wake: a **vacant** helm is taken (arm script via `gleipnir_lock_acquire`; Gná classifies an empty lock as `missing` so the reclaim takes it in place), while only a verifiably live other owner is refused as read-only. It drops its own lock on real process exit (`releaseLockIfOwned`). Gná's wake delivery is **echo-guarded**: an identical watcher message is sent at most once per drained state — when the durable queue is empty, a repeat is the same news the primary already drained and is not re-delivered, so a long stale window cannot flood the follow-up queue.

> **ONE QUEUE (2026-09-23).** The state dir is the **operator's home**, never the code tree: `$YMIR_STATE_OVERRIDE` → `$YMIR_HOME/state` → the recorded choice (`~/.config/ymir/home`) → `$HOME/Documents/ymirhome`. Every reader and writer must resolve it the SAME way — `bin/hoard-lib.sh` for shell, and the same order of authority inside `gna-pi-watch.ts`. This was once two dirs: the watcher read `$BROKK_HOME/state` (the **tree**) while the Eindri handoff (`bin/eindri-acclaim.sh`) wrote `$YMIR_STATE_DIR` (the **hoard**), so a report filled one `.wake-queue` and the watcher polled another — **the task wrote, the watcher watched, and no wake ever surfaced.** A report may be filed and still be invisible; the queue is only real when both ends agree on where it is.

> **THE POINTER IS MACHINE-LOCAL (2026-09-23).** `state/.lock-path` records the resolved session-lock path — a path that is *machine-local and per-user*, yet the pointer itself lives in the **synced** home. So a box reinstalled under a new username (e.g. `heimdallomarchy` → `heimdall`) inherits a pointer to the OLD home; both harness readers (`gna-pi-watch.ts`, `syn-watch-arm.js`) then tried to `mkdir` a foreign home and failed with `EACCES`, stranding supervision. The writer and the readers now resolve the SAME state dir (`gleipnir_state_dir` uses `bin/hoard-lib.sh` for the primary, `<home>/state` for an Eindri-home), and both readers **validate** the pointer: a path outside the current user's home is stale, is ignored, and is healed to the path this machine derives (machine-global for the primary, per-home for a seat). The `0006-lock-path-home-drift` migration heals an existing home; Eir's `hoard` surface diagnoses and mends the drift.
- **OpenCode** owns continuity in `syn-watch-arm.js` (Sýn); the coordinator is published under `globalThis.__brokkOpenCodeWatchArm` so the turn-end guard can consult it first.
- **Claude Code** uses the `Stop` hook with `"asyncRewake": true` and a long timeout to keep the arm running out of band.
- **Codex / Cursor** run `syn-turnend-guard.sh` at Stop; they do **not** own a long-lived arm (no auto re-arm).

### Part 3 — Turn-end guard

Bind the harness's "turn is about to end" event to `bin/syn-turnend-guard.sh`. If the guard prints the recovery instruction and exits **2**, the adapter must re-prompt instead of letting the turn end blind.

```bash
bin/syn-turnend-guard.sh [--claude]
# reads Claude/Codex-shaped {"stop_hook_active":false} on stdin (ignored)
# exit 0 = supervision healthy OR never armed (inert)
# exit 2 = supervision was armed and the watcher is missing/stale; stderr carries recovery
```

The guard is **inert until the first successful arm** writes `state/.supervision-armed`:

```bash
# bin/syn-turnend-guard.sh:20
[ -f "$STATE/.supervision-armed" ] || exit 0
```

It goes stale when `now - state/.watch.heartbeat > BROKK_WATCH_HEARTBEAT_STALE_SECONDS` (default 60).

> **`$STATE` is the operator's hoard state, never the code tree (2026-09-23).**
> `bin/syn-turnend-guard.sh` resolves `$STATE` through `bin/hoard-lib.sh`, exactly
> as the watcher and the wake drain do. It once defaulted to `$BROKK_HOME/state`
> (the **tree**), so it read a stale code-tree heartbeat and fired *"turn would
> end blind"* every turn while the live watcher beat into the hoard seconds
> earlier. The marker and heartbeat live where the watcher writes them — the home.

### Part 4 — PreToolUse seatbelts

Bind the harness's pre-tool event for shell commands to the two owner scripts. Exit **2** (or throw) blocks the tool call.

```bash
bin/syn-arm-pretool-check.sh --command "<bash command>"   # denies backgrounding the watcher arm
bin/syn-cd-pretool-check.sh  --command "<bash command>"   # denies a persistent escaping `cd`
```

Both are **v0 inert-by-default** contracts: `syn-arm-pretool-check.sh` blocks only a command that backgrounds `syn-watch-arm.sh`; `syn-cd-pretool-check.sh` blocks only `cd .../../`. Owner scripts hold the policy; adapters only relay.

**A third seatbelt guards the assets** — `bin/syn-asset-pretool-check.sh` denies an
`edit`/`write` of a governed path until its owning asset has been read in the
session (reads are recorded in `state/asset-reads`).

```bash
bin/syn-asset-pretool-check.sh --path "<file>"          # exit 2 when the asset is not loaded
bin/syn-asset-pretool-check.sh --note "<asset path>"     # record an asset as read
```

Who governs what:

```
governed[6]{path,load_first}:
  "bin/ymir-install.sh",".agents/skills/galdr-ymirsystem/assets/installation.md"
  "apps/hlidskjalf/**",".agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md"
  "bin/mimir*",".agents/skills/galdr-ymirsystem/assets/memory-well.md"
  "bin/nornir-* | config/cron.yaml",".agents/skills/galdr-ymirsystem/assets/nornir-jobs.md"
  "bin/valknut-load.sh | .pi/** | .opencode/**",".agents/skills/galdr-ymirsystem/assets/harness-integration/README.md"
  "bin/smidja* | .agents/skills/smidja/**",".agents/skills/galdr-ymirsystem/assets/smidja.md"
```

The Pi extension `.pi/extensions/syn-turnend-guard.ts` relays it: `read` of an
asset is recorded, and an `edit`/`write` of a governed path is blocked with the
reason. The guard's own liveness check is **zombie-aware** too — `/proc/<pid>/stat`
field 3 (Z/X = a killed-but-unreaped or dead holder) fails a stale lock even when
`kill(0)` would report the pid alive, with `kill(0)` as the fallback when `/proc`
is unavailable. The same routes are stated in `AGENTS.md` and printed in the session
digest under `ASSET ROUTING`, and `compliance-check.sh` fails on a governed file
changed without its asset (the `assets` gate).

### Part 5 (optional) — Re-arm / stop auto-arm

Some harnesses cannot synchronously own the watcher at Stop. The supported pattern is an **async rewrite** hook (Claude Code `"asyncRewake": true`; Cursor `followup_message` loop) that re-runs the arm and surfaces actionable output on stderr. If the harness has no such mechanism, do not fake it — declare the harness **turn-end-only** (Codex, Cursor) and rely on `einherjar-spawn.sh` fail-closed dispatch.

---

## 4. The adapter matrix

Legend: ✅ implemented · ⚠️ partial/inert-by-design · ❌ not implemented.

| Harness | Session-open injection | Watch arm owner | Turn-end guard | Pretool (arm) | Pretool (cd) | Re-arm |
|---|---|---|---|---|---|---|
| **OpenCode** | ✅ `.agents/harness/opencode/plugins/saga-sessionstart.js` | ✅ `.agents/harness/opencode/plugins/syn-watch-arm.js` (`session.idle`, coordinator key) | ✅ `.agents/harness/opencode/plugins/syn-turnend-guard.js` | ✅ `syn-pretool-check.js` | ✅ `syn-cd-check.js` | ✅ plugin-owned retries |
| **Pi** | ✅ `.pi/extensions/syn-turnend-guard.ts` (`before_agent_start`) | ✅ `.pi/extensions/gna-pi-watch.ts` (`gna_watch_arm` tool) | ✅ same extension (`agent_settled`) | ✅ same extension (`tool_call`) | ✅ same extension (`tool_call`) | ✅ Gná retry/backoff |
| **Claude Code** | ✅ `.claude/settings.json` `SessionStart` | ✅ `Stop` + `syn-watch-arm.sh --restart` (`asyncRewake`) | ✅ `Stop` + `syn-turnend-guard.sh --claude` | ❌ | ❌ | ✅ async rewake |
| **Codex** | ✅ `.codex/hooks.json` `SessionStart` | ⚠️ no long-lived arm | ✅ `Stop` + `syn-turnend-guard.sh` | ✅ `PreToolUse` matcher `Bash` | ✅ `PreToolUse` matcher `Bash` | ❌ |
| **Cursor** | ✅ `.cursor/hooks.json` `sessionStart` | ⚠️ interactive only | ✅ `stop` → `{"followup_message":...}` | ✅ `preToolUse` matcher `Shell` | ✅ `preToolUse` matcher `Shell` | ❌ |
| **Grok** | ❌ no `.grok/` in Ymir | ❌ | ❌ | ❌ | ❌ | ❌ |

### Adapter files at a glance

| Path | Exports / shape | Contract parts |
|---|---|---|
| `.agents/harness/opencode/plugins/saga-sessionstart.js` | `export const SagaSessionstart` | 1 |
| `.agents/harness/opencode/plugins/syn-watch-arm.js` | `export const SynWatchArm` | 2 |
| `.agents/harness/opencode/plugins/syn-turnend-guard.js` | `export const SynTurnendGuard` | 2 (consult coordinator), 3 |
| `.agents/harness/opencode/plugins/syn-pretool-check.js` | `export const SynPretoolCheck` | 4 (arm) |
| `.agents/harness/opencode/plugins/syn-cd-check.js` | `export const SynCdCheck` | 4 (cd) |
| `.agents/harness/opencode/plugins/lib/rodd-operational-input.js` | `encodeRoddOperationalInput(root, kind, content)` | shared wire |
| `.pi/extensions/syn-turnend-guard.ts` | `export default function (pi: ExtensionAPI)` | 1, 3, 4 |
| `.pi/extensions/gna-pi-watch.ts` | `export default function (pi: ExtensionAPI)` | 2 |
| `.pi/extensions/ro.ts` | Ró — the calm presentation preference (`/calm`), state/ro | user |
| `.pi/shared/extensions/open-editor.ts` | `/edit [path]` and `ctrl+shift+e` — opens files from cwd in the Allfather's editor; strictly user-facing, no LLM tool. **Resolution:** `$VISUAL` → `$EDITOR` → the first editor that exists (`code cursor zed subl nvim vim hx helix nano micro emacs vi`), so a host that is not Omarchy — where Omarchy's own launcher or a bare `vi` may be absent — still gets a working editor instead of an ENOENT | user |
| `.pi/shared/extensions/herdr-agent-state.ts` | reports pane agent lifecycle state to herdr | 2 |
| `.pi/shared/extensions/todo.ts` | the todo surface | user |
| `.pi/shared/extensions/ymir-subagents.ts` | **the Eindri roster as a Pi tool** — reads the canonical `.agents/agents/*.md` tree and exposes every figure through a `subagent` tool (and a `/subagents` command). See "Pi has no agent loader" below | user |
| `.pi/shared/extensions/lib/rodd-operational-input.ts` | `encodeRoddOperationalInput`, `classifyRoddOperationalText`, `classifyRoddCurrentOperationalText` | shared wire |
| `.pi/extensions/lib/vordr-sessionstart-supervisor.mjs` | detached child supervisor (Vörðr) | 1 (transport) |
| `.claude/settings.json` | `hooks.SessionStart[]`, `hooks.Stop[]` | 1, 3, 5 |
| `.codex/hooks.json` | `hooks.SessionStart[]`, `hooks.PreToolUse[]`, `hooks.Stop[]` | 1, 3, 4 |
| `.cursor/hooks.json` | `hooks.sessionStart[]`, `hooks.preToolUse[]`, `hooks.stop[]` | 1, 3, 4 |

---

## 5. The environment contract

Every adapter and script resolves the same runtime roots. The overrides exist so tests and realm homes can relocate the runtime without touching the launcher.

| Variable | Meaning | Default |
|---|---|---|
| `BROKK_ROOT_OVERRIDE` | tracked code root (holds `bin/`, `AGENTS.md`) | resolved from script location |
| `BROKK_HOME` | private home (holds `data/ state/ config/`) | `BROKK_ROOT_OVERRIDE` or repo root |
| `BROKK_STATE_OVERRIDE` | state dir | `$BROKK_HOME/state` |
| `BROKK_DATA_OVERRIDE` | data dir | `$BROKK_HOME/data` |
| `BROKK_CONFIG_OVERRIDE` | config dir | `$BROKK_HOME/config` |
| `BROKK_REALM` | active realm | `data/realm.md` line 1, else `way-of` |
| `BROKK_SESSION_PID` | **live harness PID** bound by the session lock | `${BROKK_SESSION_PID:-$$}` |
| `BROKK_SESSIONSTART_INELIGIBLE` | `1` makes Pi's prerequisite exit 3 | unset |

`BROKK_SESSION_PID` is the load-bearing variable. The lock must bind to the **live harness process**, not the short-lived digest helper: Pi/OpenCode adapters pass `BROKK_SESSION_PID=String(process.pid)` into the spawned digest/arm child (`.pi/extensions/syn-turnend-guard.ts:277`, `.agents/harness/opencode/plugins/syn-watch-arm.js:428`). `bin/gleipnir-lock-lib.sh` writes it to `state/.lock`.

Full variable inventory: [`../runtime-components.md`](../runtime-components.md) §5.

---

## 6. Fail-closed dispatch rules

Dispatch is owned by `bin/einherjar-spawn.sh` (Norse: **Einherjar**). It **never silently falls back** to an unverified harness.

| Rule | Where | Behavior |
|---|---|---|
| Verified adapter set | `bin/einherjar-spawn.sh:53` | `VERIFIED_HARNESSES='opencode pi pi-signed'` |
| Unverified harness | `bin/einherjar-spawn.sh:224-232` | `error: harness '<h>' is not verified for direct launch` → exit 1 |
| Missing executable | `bin/einherjar-spawn.sh:233-236` | `error: harness '<h>' executable not found on PATH` → exit 1 |
| Missing auth/dependency | adapter scripts | report a plain reason; never a silent fallback |
| Raw launch escape hatch | `bin/einherjar-spawn.sh:207-211` | a `--harness` value containing whitespace is treated as a raw command, warns loudly, and is *not* on the verified set |
| Active dispatch profiles | `bin/einherjar-spawn.sh:212-214` | if `config/eindri-dispatch.json` exists, a fresh spawn **must** pass an explicit `--harness` resolved from its rules |
| Brief/flag drift | `bin/einherjar-spawn.sh:327-335` | refuses a ship launch whose brief's `Delivery contract: mode=<m>` disagrees with `--mode` |
| Isolation dependency | `bin/einherjar-spawn.sh:340-359` | `--isolation on` requires docker + `utgard-runner:latest`, else exit 1; `auto` reports the decision |

**Adding a harness to the verified set is a deliberate act:** implement all four contract parts, smoke-test them, then add the adapter name to `VERIFIED_HARNESSES` in `bin/einherjar-spawn.sh` (see §8).

---

## 7. How to add a new harness (step-by-step)

A harness is a runtime that can host Brokk. Adding one is a five-stage task.

### Stage 0 — Inventory the harness's lifecycle

Answer these before writing anything:

1. Does a **session-open** hook exist, and can it inject stdout into context (run-tier) or only post a message (nudge-tier)?
2. Does an **idle/turn-end** event exist for the guard?
3. Can a **long-lived arm process** be spawned at Stop, or only a synchronous hook?
4. Is there a **pre-tool / before-tool** event for shell commands, and can it block?
5. What env var names does the harness export (project dir, workspace root, agent marker)?

### Stage 1 — Add detection to Hamr

`bin/hamr-harness.sh` (Norse: **Hamr**, "the shape a being wears") is the single source of harness identity. Two layers, in precedence order:

- **Layer 1 — verified env markers** (`bin/hamr-harness.sh:112-135`). Add your marker *after* the Cursor/Claude/Pi/Grok markers, documenting the version you verified it on.
- **Layer 2 — process ancestry** (`bin/hamr-harness.sh:136-169`). Add a `*<name>*` case to the `comm` matcher and to the bare-interpreter `args` matcher.

```bash
# bin/hamr-harness.sh — Layer 1 pattern
[ "${MYHARNESS_AGENT:-}" = "1" ] && { echo myharness; return; }
# Layer 2 pattern
case "$(basename -- "$comm")" in
  *myharness*) echo myharness; return ;;
esac
```

Reuse the shared Cursor identity helpers (`hamr_cursor_process_matches`, `hamr_cursor_argv0_for_pid`) if your harness shares an interpreter.

### Stage 2 — Write the adapter

Pick the closest existing adapter in the table (§4) and mirror its structure. The rules are non-negotiable:

- **Resolve the root** the same way: prefer `worktree` → `git -C <dir> rev-parse --show-toplevel` → `realpathSync(dir)`.
- **Call only `bin/` owner scripts.** Never re-implement digest, arm, guard, or classification logic.
- **Session-open:** call `bin/saga-sessionstart-run.sh`. Never `bin/saga-session-start.sh` directly from an adapter.
- **Watch arm:** require a live lock. If the arm reports `read-only`, stop; do not retry.
- **Turn-end:** re-prompt on exit 2. On any other exit, do nothing.
- **Seatbelts:** relay exit 2 as a block.
- **Encode operational text** with the Rödd bridge (`lib/rodd-operational-input.*`) before delivery.

### Stage 3 — Register the hooks

Create the harness's config file (`.<harness>/...`) matching the real schema. See the deep-dive file for the exact JSON shape per harness. The absolute rule: **the hook must be self-locating** (use the harness's own project-dir env var or `pwd -P`) and must **no-op safely** when the runtime is absent.

### Stage 4 — Verify (all four parts)

Run the commands in §9 and confirm the four contract parts. Do not mark the adapter done on a happy-path session-open alone; a guard that never fires is indistinguishable from a guard that is not wired.

### Stage 5 — Mark verified + document

1. Add the harness name to `VERIFIED_HARNESSES` in `bin/einherjar-spawn.sh:53`.
2. Add a row to the matrix in §4 of this file and a deep-dive file next to it.
3. If you want it as the default for dispatched Eindri, set `config/eindri-harness` (one line: `<harness> [<model>] [<effort>]`).
4. Record the verified version and any marker quirks in this file's Gotchas and in `data/learnings.md`.

---

## 8. Adding a new harness to `VERIFIED_HARNESSES`

The verified set is the fail-closed gate. Edit exactly this line and nothing else:

```bash
# bin/einherjar-spawn.sh:53
VERIFIED_HARNESSES='opencode pi pi-signed'
```

Notes:

- `pi-signed` is a Pi variant (`BROKK_PI_HARNESS=pi-signed` / `FM_PI_HARNESS`); it maps to `pi` in `einherjar-spawn.sh`'s inline fallback but is a distinct token for the launch command (`bin/einherjar-spawn.sh:419-430`).
- Adding a raw command is **not** a substitute: `--harness "mycmd --flag"` bypasses verification and warns.

---

## 9. Verification

### Syntax and schema

```bash
cd "$BROKK_HOME"
for f in bin/*.sh; do bash -n "$f" || echo "SYNTAX FAIL: $f"; done
python3 -m json.tool config/eindri-dispatch.json >/dev/null && echo "dispatch JSON ok"
python3 -m json.tool .claude/settings.json   >/dev/null && echo "claude JSON ok"
python3 -m json.tool .codex/hooks.json       >/dev/null && echo "codex JSON ok"
python3 -m json.tool .cursor/hooks.json      >/dev/null && echo "cursor JSON ok"
```

### Session-open injects, Go digest

```bash
# Run as the harness would; it must print the Sága digest and exit 0.
bin/saga-sessionstart-run.sh --source startup | head -n 20
echo "exit=$?"

# Re-emit path after a completed startup:
test -f state/.session-start-complete && bin/saga-sessionstart-run.sh --source compact | head -n 3
```

### Watch arm arms, heartbeat, and exits on a wake

```bash
# In one shell (must own the lock):
bin/syn-watch-arm.sh --restart        # prints "watcher: started pid=... recovery-generation=..."
test -f state/.supervision-armed && echo "armed marker written"
test -s state/.watch.heartbeat && echo "heartbeat written"
# In another shell, drop a wake and watch the arm exit with "signal: wake queue":
: > state/.wake-queue
```

### Turn-end guard

```bash
# Inert before first arm:
rm -f state/.supervision-armed
echo '{"stop_hook_active":false}' | bin/syn-turnend-guard.sh; echo "expected 0, got $?"
# Armed but stale heartbeat → exit 2:
touch state/.supervision-armed
rm -f state/.watch.heartbeat
echo '{"stop_hook_active":false}' | bin/syn-turnend-guard.sh; echo "expected 2, got $?"
```

### Seatbelts

```bash
bin/syn-arm-pretool-check.sh --command 'bin/syn-watch-arm.sh --restart &'; echo "expected 2, got $?"
bin/syn-arm-pretool-check.sh --command 'bin/syn-watch-arm.sh --restart';  echo "expected 0, got $?"
bin/syn-cd-pretool-check.sh  --command 'cd ../../etc';                    echo "expected 2, got $?"
bin/syn-cd-pretool-check.sh  --command 'ls -la';                          echo "expected 0, got $?"
```

### Session lock ownership

```bash
bin/saga-session-start.sh | sed -n '1,12p'   # LOCK section: held vs READ-ONLY
```

---

## 10. Gotchas

- **The digest helper must never hold the lock.** Bind `BROKK_SESSION_PID` to the live harness process or a second session will read the lock as stale and mutate shared state.
- **`saga-session-start.sh` acquires the lock but never releases it.** Release is the harness's business (process exit). A refused lock means **read-only**: no spawn, steer, merge, drain, or repair.
- **Don't call `bin/saga-session-start.sh` directly from an adapter.** Use `bin/saga-sessionstart-run.sh`; only the wrapper knows the source-routing rules (`startup` runs, `clear`/`compact` re-emits, `resume`/`reload`/`fork` nudges).
- **The turn-end guard is inert until `.supervision-armed` exists.** A guard test that never arms proves nothing. Arm first, then force a stale heartbeat.
- **`session.idle` fires often.** On OpenCode, the watch-arm plugin acts first and publishes `globalThis.__brokkOpenCodeWatchArm`; the guard plugin consults it and only calls `bin/syn-turnend-guard.sh` when the coordinator could not arm. Calling the guard first produces a false "turn would end blind" prompt during normal re-arms.
- **Never background the arm from the model's bash tool.** `syn-arm-pretool-check.sh` denies it; the adapter owns continuity. The arm is a plugin/extension child, not a tool call.
- **Exit-code semantics differ by host.** Claude's `SessionStart` exit 2 blocks initialization, so the run wrapper always exits 0 on the transport path; Pi's prerequisite uses exit 3 internally so preflight can distinguish a stand-down from a silent failure.
- **`hamr-harness.sh` has no `crew` subcommand — its subcommand is `eindri`.** `bin/einherjar-spawn.sh:170` calls `hamr-harness.sh crew`, which falls through to `detect_own` (`bin/hamr-harness.sh:231-236`); see §11. Until that call is fixed, `config/eindri-harness` is only honoured by the inline fallback, not the Hamr path.
- **Plugin auto-loading is path-based, not declared.** OpenCode loads `.agents/harness/opencode/plugins/*.js` automatically; there is no `plugin` array in `opencode.json`. The `package.json` only declares `"type": "module"`.
- **Grok is not wired in Ymir.** Upstream Brokk ships `.grok/hooks/*.json`; Ymir has no `.grok/`. Treat Grok as unverified (see §11).
- **Windows timing.** OpenCode and Pi raise the arm-ready budget to 35s on `win32` so a slow Git Bash cold start is not SIGTERMed mid-confirmation (`.agents/harness/opencode/plugins/syn-watch-arm.js:17-19`, `.pi/extensions/gna-pi-watch.ts:91-94`).

---

## 11. Known code-vs-doc disagreements (truth is the code)

| Plan 29 says | Code says (truth) |
|---|---|
| `.agents/harness/opencode/plugins/syn-sessionstart.js` | actual file is `.agents/harness/opencode/plugins/saga-sessionstart.js` |
| `.agents/harness/opencode/plugins/gna-watch-arm.js` (plan §1) | actual file is `.agents/harness/opencode/plugins/syn-watch-arm.js` (OpenCode's watcher is **Sýn**, not Gná; Gná exists only on Pi) |
| Plan §13 "still to build: `bin/hamr-harness.sh`; the `.opencode`/Claude/Codex/Cursor adapters; `bin/einherjar-spawn.sh`; …" | all of these are **now landed**; plan §13 is stale |
| Digest §6 lists 9 stages including **NETWORK CHECKS** and **FLEET DIGEST from `data/backlog.md`** | `bin/saga-session-start.sh` currently prints **8** sections (LOCK, BOOTSTRAP, WAKE QUEUE, SUPERVISION, FLEET DIGEST, CONTEXT DIGEST, CRON START, NEXT STEP); there is **no NETWORK CHECKS section**, and the fleet digest counts `state/*.meta` + `docs/masterplan.md` orders, not `data/backlog.md` |
| Plan §7 "Cursor … run interactive only (no headless turn-end)" | `.cursor/hooks.json` **does** implement `sessionStart` (`additional_context`) and `stop` (`followup_message`) |
| Plan §7 "Codex … bounded foreground checkpoint … nudge-tier" | `.codex/hooks.json` implements run-tier `SessionStart` + `PreToolUse` + `Stop` |
| Plan §7 "Grok — project hooks (`grok --trust`)" | no `.grok/` exists in Ymir; Grok is unimplemented |
| Plan §7 "Claude Code … SessionStart + Stop hooks" | correct, but Ymir's `.claude/settings.json` has **no `PreToolUse`** seatbelt entries (upstream Brokk does) |

The authoritative interface is always the code listed in [`../runtime-components.md`](../runtime-components.md); report drift there.

---

## 12. Provenance

The adapter pattern is ported from the validated upstream **Brokk** agent-distro harness adapters (`bin/fm-harness.sh`, `bin/fm-sessionstart-run.sh`, `.agents/harness/opencode/plugins/fm-primary-*.js`, `.pi/extensions/fm-primary-*.ts`, `.claude/settings.json`, `.codex/hooks.json`, `.cursor/hooks.json`, `.grok/hooks/*.json`). Ymir adopts the *mechanism* and renames every component per plan 29 §12 (Sága, Sýn, Gná, Vörðr, Rödd, Gleipnir, Hamr, Einherjar, Erindi, Vör, Nornir). The upstream names (`fm-*`, "Allfather") are provenance only and must never name a Ymir component.

---

## 13. The Well — memory for every harness (engram)

The well is **Mimirsbrunn**, backed by the validated OSS engine **engram**. It is
ONE store and it lives in the hoard — `$YMIR_HOME/hodd/memory/kaia.engram` —
reached two ways. Every reader resolves it through `hoard_memory_store`
(bin/hoard-lib.sh) or an explicit `ENGRAM_DB`; the rendered `.pi/mcp.json`
carries the hoard path (`__YMIR_HOME__/hodd/memory/kaia.engram`). The well
rides the private vault between the Allfather's computers as one store — the
legacy `memory/kaia.engram` duplicates are struck.

**HTTP bridge (`:4602`)** — `bin/mimir-bridge.py`, raised by
`bin/mimir-bridge.sh` (and by `scripts/start.sh` + `bin/saga-session-start.sh`).
It wraps the engram library so the gate API, `bin/mimir.sh`, and
`bin/mimir-ingest.sh` can drink over the small HTTP contract:

```
GET  /health                 -> {status, store, episodes, agents}
GET  /recall?q&k&mode        -> {results:[{score, distance, episode}]}
GET  /recent?limit           -> {episodes:[...]}
GET  /timeline?entity        -> {facts:[...]}
GET  /inspect                -> {episodes, agents, store}
POST /observe {content,...}  -> {id}
```

The Pi extension `ymir-well.ts` (shared, deployed) drinks over this same bridge.
`bin/saga-sessionstart-run.sh` raises the bridge (idempotent) on **every**
session open — startup, clear/compact re-emit and resume alike — so `:4602`
listens before the session binds and the extension's `session_start` probe
usually succeeds on its first try. The probe still retries `/health` up to six
times at one-second spacing because a birth race (or a bridge that died since
the last open) is not an outage. A refused or timed-out connection is shaped as
the same `{ok:false}` answer every HTTP miss uses (status 0), so `well_recall` /
`well_observe` report a down well into the thread instead of throwing out of it.
Each call carries a 60s abort cap (`YMIR_WELL_TIMEOUT_MS` to tune) so a
cold-start embedding-model fetch cannot strangle a recall on its first breath.

**MCP server (stdio)** — `engram-mcp --db <store> --agent-id <harness>`, so any
MCP-capable harness gets `remember`, `recall`, `why`, `forget`, `stats` with no
integration code. Registered per harness (each writes under its own agent id):

| Harness | Config | Agent id |
|---|---|---|
| OpenCode | `opencode.json` → `mcp.engram` (+ `~/.config/opencode/opencode.json`) | `opencode` |
| Pi | `.pi/mcp.json` (pass `pi --mcp-config .pi/mcp.json`) | `pi` |
| Claude Code | `~/.claude.json` → `mcpServers.engram` | `claude` |
| Cursor | `~/.cursor/mcp.json` → `mcpServers.engram` | `cursor` |
| Codex | `~/.codex/config.toml` → `[mcp_servers.engram]` | `codex` |

The engine needs the `mcp<2` SDK for `engram-mcp` (v2 renamed `FastMCP` to
`MCPServer`, which breaks engram 1.x/2.x):
`python3 -m pip install --user --break-system-packages 'mcp<2'`.

Rule: **drink before you act, water it after** — recall on the way in, and
`POST /observe` (or the `remember` MCP tool) after a lesson lands.

---

## 14. Agent locations — `.agents/agents` is the source of truth

Agent profiles live **only** in `.agents/agents/*.md` (the canonical, with the
harness config like `mode`/`model`/`permission` in their frontmatter). The
harness directories **bind** them by symlink — they are never hand-written
duplicates:

- OpenCode: `.opencode/agents/<name>.md` → `../../.agents/agents/<profile>.md`
- Pi: `.pi/agents/<profile>.md` → the same canonical files

`bin/valknut-load.sh` creates the symlinks (`--opencode`, `--pi`, `--global`,
`--all`). **Every harness gets EVERY agent** — claude, codex, cursor and opencode
are bound by the same loader pass as pi, so no harness is left holding a
hand-made subset. Naming differs by harness and must be respected:

> **Rebind on every install, update and merge (2026-09-23).** The harnesses load
their surfaces from their **own** homes — Pi reads `${HOME}/.pi/agent/extensions/`
— so a change merged into the repo is INVISIBLE to a running harness until the
bind re-runs. A hand-copied extension was the symptom; the cure is to make the
bind automatic: `bin/ymir-install.sh` runs `valknut-load.sh --install` (which
seats a **post-merge** hook), `bin/groa-update.sh` runs `--all --global` after
every pull, and the hook runs it after every merge. Two further truths:
> **a running session keeps the code it loaded** (so a fixed extension is live
> from the NEXT pi session, never the current one), and the hooks dir is found by
> asking git (`rev-parse --git-path hooks`) — in a worktree `.git` is a file and
> the shared hooks live in the main repo.

```
agent_binding[5]{harness,dir,name_rule}:
  "opencode",".opencode/agents/","the frontmatter `name:` — bragi.md -> bragi-marketer.md"
  "pi",".pi/agents/","the profile file name — bragi-marketer.md"
  "claude",".claude/agents/","the profile file name"
  "codex",".codex/agents/","the profile file name"
  "cursor",".cursor/agents/","the profile file name"
```

To change an agent, edit `.agents/agents/*.md` and re-run the loader; never edit
a harness directory (they are all links).

### Skill location — the same law, one tree

Skills have **one** tree too: `.agents/skills/`. Every harness reaches it, each
by the mechanism that harness actually reads — and a harness that silently
loads nothing is invisible from the code, so `compliance-check.sh`'s `harnesses`
gate asserts all four:

| Harness | How it reaches `.agents/skills` |
|---|---|
| **opencode** | `skills.paths: [".agents/skills"]` in `opencode.json` (the loader merges it in and re-asserts it on every run) |
| **pi** | **native discovery** — it walks up from the cwd to `.agents/skills` (and `~/.agents/skills`). No link, no config: a second root under `.pi/` would invite double-loading, exactly as the extensions rule warns |
| **claude · codex · cursor** | `<harness>/skills -> ../.agents/skills`, created by `bin/valknut-load.sh` (their project scope is their own directory) |

**Do not** copy a `SKILL.md` into a harness directory: a copy is drift, and a
nested `SKILL.md` carrying frontmatter is loaded as a *second, phantom* skill by
every recursive scanner (the `harnesses` gate refuses it).

### opencode.json has two writers — and neither may overwrite

`opencode.json` is untracked (it carries absolute paths) and two things write it:

```
writers[2]{writer,owns}:
  "bin/valknut-load.sh","STRUCTURE — the base keys, the agent blocks, the skills path; rendered from opencode.json.example"
  "bin/agents-config.sh apply","the ROSTER — providers and per-agent models, from config/agents.yaml"
```

**Both merge; neither overwrites.** The loader's `config_out` adds missing keys (
deep, `setdefault`-style), ensures `skills.paths`, and re-asserts nothing else;
`agents-config` does the same for providers and models — and it writes **only
OpenCode agents** into `opencode.json`. A `pi` (or `hermes`) agent's model is that
harness's own id (e.g. `llamacpp/qwen3.5-9b`), which OpenCode cannot resolve, so
those agents are deliberately left out rather than handed to OpenCode broken. This is not tidiness —
the loader used to re-render from the example with `sed` + `mv`, and because the
example carried only `llama.cpp`, **every loader run deleted the Apodex
provider**, which lived only in the live file. A blind render of a file two
writers share is a silent data loss; the merge is the fix.

## 15. The Eindri roster (bound agents)

Every skill names an owner agent in `.agents/skills/README.md`; the fleet below
is the full set of canonical profiles, all bound into all five harnesses.

Canonical profiles in `.agents/agents/*.md`, bound as symlinks:

```
einherjar[20]{figure,craft,domain,engine}:
  "Brokk","primary — the bellows","ymirlabs","—"
  "Sindri","developer / smith","brokkforge","Chrome DevTools"
  "Bragi","marketer / skald","utgard","Firecrawl + browser-use (+ Scrapy)"
  "Hnoss","designer / shaper","utgard","OpenDesign"
  "Huginn","researcher / sage","muninn","—"
  "Mímir","planner / the wise","ymirlabs","—"
  "Forseti","reviewer / the just","runestone","—"
  "Snotra","documenter / the wise-woman","runestone","—"
  "Kvasir","scout / the knowing","ymirlabs","—"
  "Galdr","builder — CLI ergonomics","ymirlabs","—"
  "Týr","judge — the 10 principles + the gates","runestone","—"
  "Sága","seeress — bearings + recap","ymirlabs","—"
  "Muninn","rememberer — memory curation","muninn","—"
  "Urðr","fate — the hold lifecycle","ymirlabs","—"
  "Frigg","knowing — consent gate","ymirlabs","—"
  "Vör","aware — diagnostics","ymirlabs","—"
  "Sýn","seeing — stuck-worker recovery","ymirlabs","—"
  "Jörð","grounded — project registry","ymirlabs","—"
  "Gróa","renewer — self-update","ymirlabs","—"
  "Völundr","master smith — Smíðja's orchestrator","brokkforge","—"
```

Bind with `bin/valknut-load.sh --all` (OpenCode: `.opencode/agents/<name>.md`; Pi:
`.pi/agents/<profile>.md`) — never edit the harness dirs.

## Pi has no agent loader (2026-09-17)

**Pi core does not load `.pi/agents/`.** Agent loading in Pi is a *package*
(`pi-agents`, `pi-agent-mode`, `pi-simple-agents`), not a core feature, and Ymir
installs none of them. So `.pi/agents/` held twenty correct profile links that
**nothing in Pi ever read** — the same failure as OpenCode's singular
`.opencode/agent/`, arrived at from the other side.

The fix lives in the repo, not in a root-pi package: **`.pi/shared/extensions/ymir-subagents.ts`**
discovers the canonical `.agents/agents/*.md` tree itself and registers a
`subagent` tool. A call runs the chosen figure as a nested model call in the
current session — the figure's markdown body is its system prompt, its
frontmatter `model:` picks the model where the machine serves it.

```
subagent({ agent: "kvasir", task: "find every AGENTS.md" })   # dispatch
subagent({})                                                   # list the roster
/subagents                                                     # list the roster
```

Rules this extension follows, learned the hard way:

- **No imports.** `@earendil-works/pi-coding-agent` is **not installed as a
  package**, so an extension that imports its types cannot load at all. Every
  working extension in this tree takes `pi` as `any` and declares tool
  `parameters` as a plain JSON schema object. `typebox` *is* installed, but the
  plain object needs nothing.
- **One home.** It lives in `.pi/shared/extensions/` (deployed), never in
  `.pi/extensions/` — a copy in both makes pi refuse the duplicate tool.
- **The canonical tree is the source.** It reads `.agents/agents/`; it never
  copies from it (Rule 02).

### A rename that left a reader behind (same day)

`skuld-branch-supervision.ts` imported `calmTranscriptClassIsVisible` and
`CalmPresentationState` from `./lib/ro-visibility.ts`, but that module exports
`roTranscriptClassIsVisible` and `RoPresentationState` — the names were renamed
and the importer was not. Pi refuses the **whole extension** at load with
`does not provide an export named …`, so Skuld's supervision branch was dead in
every session while nothing reported it. Fixed in the same change.

**Check every extension actually loads**, not just that its file exists:

```bash
cd ~/.pi/agent/extensions
for f in *.ts; do
  node --input-type=module --eval "import('file://$PWD/$f').then(()=>console.log('$f LOADS')).catch(e=>console.log('$f FAIL: '+e.message.split('\n')[0]))"
done
```

Run it after every deploy. A module that cannot resolve is invisible from the
file listing, and pi reports it only as a startup line that scrolls away.



Pi loads **both** the project `.pi/extensions/` and the global
`~/.pi/agent/extensions/` directories; because it does not de-duplicate by
extension or tool name, an extension present in both makes `pi` exit with
`Tool "<name>" conflicts with …` and **no agent can be seated** (herdr reports
"the pane must sit at an interactive shell prompt", a confusing symptom).

Rule: **one home per extension.**

- Shared extensions (`todo.ts`, `herdr-agent-state.ts`, `open-editor.ts`) live
  **only** in `~/.pi/agent/extensions/` — used by every project, Ymir and
  Omarchy alike.
- The repo `.pi/extensions/` holds **only Ymir-unique** extensions
  (`gna-pi-watch.ts`, `ro.ts`, `skuld-branch-supervision.ts`,
  `syn-turnend-guard.ts`, `lib/`).
- Never copy a shared extension back into the repo; that re-arms the collision.

**Shipping the shared extensions (added 2026-09-12).** A rule that keeps the
extensions outside the repo would also keep them from every new operator, so the
repo carries their **source** at `.pi/shared/extensions/` — a path pi does not
load, therefore collision-free — and the loader deploys it into the single home:

```bash
bin/valknut-load.sh --pi      # deploys .pi/shared/extensions/*.ts -> ~/.pi/agent/extensions/
```

The deploy copies (never links: a broken link would silently disable a tool),
skips files that are already identical, and reports what it placed. It runs
whenever the Pi surface is bound, with or without `--global`. Adding a shared
extension is therefore two steps: put the source in `.pi/shared/extensions/`, and
let the loader place it — **never** place it in `.pi/extensions/`.

**The deployed copy must be told where `bin/` is (2026-09-19).** A deploy that
copies an extension without telling it where its own `bin/` lives is not a deploy.
Every extension resolved its distro root as `resolve(extensionDir, "../..")` — and
from `${HOME}/.pi/agent/extensions/` that reaches `${HOME}/.pi`, which holds pi's
own config and **no `bin/` at all**. Each `${root}/bin/…` they exec'd was a path
that did not exist, and the failure was silent by construction: the Gná arm child
exited **127 before its first poll**, no `state/.watch.heartbeat` was ever written,
and the watch was dead while every file listing looked correct. The Sága digest was
never injected either — the turn-end guard spawns `${root}/bin/saga-sessionstart-run.sh`
from that same root.

The root is now **recorded at deploy time**: `bin/valknut-load.sh --pi` writes one
absolute root per line — most recent first, deduped, capped — to
`${HOME}/.pi/agent/extensions/.ymir-root`, and `.pi/extensions/lib/ymir-home.ts`
reads it back for all four extensions (`gna-pi-watch`, `syn-turnend-guard`, `ro`,
`skuld-branch-supervision`). Resolution order:

```
1. BROKK_ROOT_OVERRIDE · BROKK_HOME · YMIR_ROOT   — an explicit word wins
2. the recorded roots, first one that verifies
3. resolve(extensionDir, "../..")                 — the pre-pointer contract
```

A candidate counts only if it really holds `bin/syn-watch-arm.sh`, so a root that
no longer exists (a merged-and-removed Yggdrasil worktree, an uninstalled npm
prefix) is skipped rather than trusted. That is why the record is a *list*:
deploying from a worktree records the worktree **and** keeps the durable root
behind it. Nothing here is hardcoded — the record is written by the loader that
performed the deploy (Rule 07).

**The four extensions were fixed — and the lib module they import was not
(2026-09-20).** The Sep 19 mend named "all four extensions"
(`gna-pi-watch`, `syn-turnend-guard`, `ro`, `skuld-branch-supervision`) and left
`rodd-operational-input.ts` — the shared **lib** module whose
`encodeRoddOperationalInput()` those four call — still walking its own
`../../../bin/rodd-operational-input.sh`. From the deployed home that resolved
`${HOME}/.pi/bin/rodd-operational-input.sh`, which does not exist, so `spawnSync`
failed, `encode` threw, and **no RÖDD operational input was injected at all** —
not session-start, not watcher, not turn-end-guard, not branch-outcome. The fix is
the same one the four already use: the lib module resolves through
`resolveYmirRoot(resolve(dirname(import.meta.url), ".."))` — the extensions dir,
where `.ymir-root` sits. Measured before the fix: `~/.pi/bin/` absent, no arm
process, both heartbeats stale for days; after: the deployed helper resolves
`/home/zerwizomar/ymir` and `bin/rodd-operational-input.sh encode session-start`
emits a real frame. A deploy only takes effect in a **new** session — an already
running session holds the code it loaded.

Two consequences worth stating:

- **Root and home are not the same thing.** The root owns `bin/`; the home owns
  `state/` and `config/`. They are usually one tree and need not be — a private
  `$YMIR_HOME` has no `bin/` of its own, and conflating the two is exactly what
  made a deployed copy exec a path that never existed.
- **A worktree deploy never repoints the global contract.** `valknut-load.sh`
  symlinks `~/.pi/agent/AGENTS.md` at the tree it ran from; pointed into
  `.yggdrasil/<id>` it would die with the worktree and leave every later session
  with no contract at all. It now repoints only when the current target is already
  gone.

`bin/eir-doctor.sh` carries the **`harness`** surface, so this is diagnosed rather
than discovered: a record with no live root is `broken`, and `fix` re-runs
`valknut-load.sh --pi`. `bin/valknut-load.sh --status` reports the same row.

## OpenCode agent `tools` key (2026-09-12)

OpenCode requires the frontmatter `tools:` key to be an **object** of its own
built-in tools. Our profiles list Ymir capabilities (`vector_db`,
`hermes_runner`, `herder`, `yggdrasil`, `supabase`, `opendesign`,
`chrome_devtools`), which are not OpenCode tools and which OpenCode rejects as
`Expected object | undefined, got [...] tools`. Those lists are therefore carried
under **`ymir_tools:`**; permission is expressed by the `permission:` block.

## Canonical layout — the ONE remap (authoritative; do not redo)

**Source of truth is `.agents/`. Harness directories are symlinks, never copies.**

```
canonical[3]{kind,canonical,load_path}:
  "agent profiles",".agents/agents/<profile>.md",".opencode/agents/<name>.md · .pi/agents/<name>.md (symlinks)"
  "OpenCode plugins",".agents/harness/opencode/plugins/",".opencode/plugins (symlink)"
  "skills",".agents/skills/","loaded via opencode.json skills.paths"
```

Rules:
- **Edit only `.agents/`.** Never edit a file under `.opencode/` or `.pi/` — those are
  symlinks to `.agents/` (e.g. `.opencode/agents/bragi.md` links to
  `.agents/agents/bragi-marketer.md`).
- After any change: `bin/valknut-load.sh --all` to rebind.
- **OpenCode requires REAL `.opencode/{node_modules,package.json,.gitignore}`** — the
  dependency store. Symlinking them hit ELOOP + untracked files and was reverted.
- So `.opencode` holds: symlinked `agent/` + `plugins`, and the real dep store. It
  cannot be deleted; it is already minimized. No agent/profile content lives there.

## Asking the Allfather — `ask_user_question` (2026-09-12)

The system can ask the Allfather instead of guessing. Adopted (open-source-first)
from `@juicesharp/rpiv-ask-user-question` (MIT), pinned **project-locally** in
`.pi/settings.json` so every machine/user that has the repo gets it.

- Gives Pi one tool, `ask_user_question`: a terminal dialog of up to four
  questions with authored options (+ descriptions/previews), a free-text row,
  per-question and global notes, and a Submit review tab.
- Non-interactive runs simply don't see the tool (never a failing call).
- Config (read-only): `~/.config/rpiv-ask-user-question/config.json`.
- Use it at real decision points — where a wrong assumption costs a rework.

**Two extension paths, and they are not interchangeable** (2026-09-12):

| Path | Loaded by | Holds |
|---|---|---|
| `.pi/extensions/` | pi, as **project-local** extensions | the governance set: `syn-turnend-guard.ts`, `gna-pi-watch.ts`, `ro.ts`, `skuld-branch-supervision.ts` |
| `.pi/shared/extensions/` | **deployed** by `bin/valknut-load.sh --pi` into `${HOME}/.pi/agent/extensions/` | the user-facing trio: `open-editor.ts`, `herdr-agent-state.ts`, `todo.ts` |

The same extension in **both** paths makes pi exit with a tool-name conflict and
no agent can be seated — which is why the shared trio has exactly one home and is
deployed, never duplicated. Editing a path from the table above without checking
which of the two it is will edit a file that is not there.

# Pi Harness Adapter

> **Purpose:** Rebuild, verify, or extend the Pi adapter — the `.pi/extensions/*.ts` modules that inject the Sága digest before the first turn, own the Gná watcher, guard the turn end, and run the PreToolUse seatbelts on `@earendil-works/pi-coding-agent`.

Pi is a **run-tier** harness with an in-process extension API: the extension runs the digest itself and injects its output into model context before the first turn. Two tracked project extensions are required; both auto-load once the project is trusted.

---

## 1. Files

| File | Norse role | Contract parts |
|---|---|---|
| `.pi/extensions/syn-turnend-guard.ts` | **Sýn** — session-start injection + compaction re-emit + turn-end guard + PreToolUse seatbelts | 1, 3, 4 |
| `.pi/extensions/gna-pi-watch.ts` | **Gná** — watcher continuity (arm, re-arm, deliver actionable wakes) | 2 |
| `.pi/extensions/lib/vordr-sessionstart-supervisor.mjs` | **Vörðr** — detached child supervisor for the digest | 1 (transport) |
| `.pi/extensions/lib/rodd-operational-input.ts` | **Rödd** — TypeScript wire bridge | shared |
| `.pi/extensions/README.md` | prose inventory (see §11: partially stale) | — |

`.pi/extensions/` has **no** `package.json`; Pi loads the `.ts` sources directly and they import `@earendil-works/pi-coding-agent` (types), `@earendil-works/pi-tui` (Gná render), and `typebox` (tool schema).

Both extensions use `import.meta.url` to locate themselves and derive the root as `resolve(extensionDir, "../..")` — i.e. the repo root that holds `bin/`:

```ts
// .pi/extensions/syn-turnend-guard.ts:23-29
const extensionFile = fileURLToPath(import.meta.url);
const extensionDir = dirname(extensionFile);
const root = resolve(extensionDir, "../..");
const brokkHome = process.env.BROKK_HOME || process.env.BROKK_ROOT_OVERRIDE || root;
const state = process.env.BROKK_STATE_OVERRIDE || `${brokkHome}/state`;
const marker = `${state}/.pi-syn-turnend-loaded`;
const extensionVersion = `sha256:${createHash("sha256").update(readFileSync(extensionFile)).digest("hex")}`;
```

---

## 2. Required Pi lifecycle events

Pi emits the following events the adapter binds (via `pi.on?.(...)`). The adapter must tolerate optional events (`?.`) because Pi adds them across minor versions.

| Pi event | Bound in | Payload / signature | Adapter action |
|---|---|---|---|
| `session_start` | both extensions | `(event, ctx)`; `event.reason` ∈ `startup \| reload \| new \| resume \| fork` | start a session-start generation (Sýn); activate a watcher generation (Gná) |
| `before_agent_start` | Sýn | `(_event, ctx)` | claim and return the digest as a message (`{ message }`) |
| `session_compact` | Sýn | `(_event, ctx)` | create a `compact` generation and `pi.sendMessage(...)` the re-emit |
| `session_shutdown` | both | `()` | stop the active generation (Sýn/Gná) |
| `agent_settled` | Sýn | `()` | run `bin/syn-turnend-guard.sh`; on exit 2, `pi.sendUserMessage(content,{deliverAs:"followUp"})` |
| `tool_call` | Sýn | `(event)`; `event.toolName`, `event.input.command` | for `bash`, run cd-check then arm-check; return `{block:true, reason}` on exit 2 |

Sýn also registers a `process.once("exit", ...)` cleanup that SIGKILLs the digest process group.

### 2.1 `session_start` source mapping (Sýn)

```ts
// .pi/extensions/syn-turnend-guard.ts:522-534
pi.on?.("session_start", (event, ctx) => {
  const reason = String(event.reason ?? "");
  const source = reason === "startup"
    ? startupRebuildSource(ctx) ?? "startup"     // maps -c/-r/--session/--fork to resume/fork
    : { new: "clear", resume: "resume", fork: "fork" }[reason];
  markLoaded();
  if (!source) return;                            // reload → no new generation
  sessionstartGeneration = createSessionstartGeneration(source, sessionIdFromContext(ctx));
});
```

- `reason === "new"` (Pi `/new`) → `clear` → wrapper re-emits context.
- `reason === "reload"` → no generation (prior context kept).
- `reason === "resume" | "fork"` → a nudge, not a full run.
- `reason === "startup"` is refined by `startupRebuildSource(ctx)`: a restored-session timestamp older than `performance.timeOrigin` plus `-c/--continue`, `-r/--resume`, `--session`, `--session-id`, or `--fork` yields `resume`/`fork`.

### 2.2 `before_agent_start` delivery (Sýn)

```ts
pi.on?.("before_agent_start", async (_event, ctx) => {
  const generation = sessionstartGeneration;
  if (!generation) return;
  const message = await claimSessionstartMessage(generation, ctx);
  return message ? { message } : undefined;
});
```

The returned message is a `syn-sessionstart-nudge` `SessionstartMessage` with encoded content. `claimSessionstartMessage` refuses to deliver when the generation was superseded or the session id changed.

### 2.3 `session_compact` (Sýn)

Manual compaction is idle and auto-compaction may retry without another `before_agent_start`, so the compact handler creates its own generation and calls `pi.sendMessage(message)` directly (`.pi/extensions/syn-turnend-guard.ts:546-557`).

### 2.4 `agent_settled` turn-end guard (Sýn)

```ts
pi.on("agent_settled", async () => {
  if (guardFollowupActive) { guardFollowupActive = false; return; }
  const result = await runGuard();                 // spawns bin/syn-turnend-guard.sh, stdin {"stop_hook_active":false}
  if (result.code !== 2) return;
  guardFollowupActive = true;
  const content = encodeRoddOperationalInput("turn-end-guard",
    "TURN WOULD END BLIND - supervision is off. ...\n\n" + result.stderr);
  await pi.sendUserMessage(content, { deliverAs: "followUp" });
});
```

`guardFollowupActive` suppresses the immediate re-fire after the guard's own follow-up creates another settle.

### 2.5 `tool_call` seatbelts (Sýn)

```ts
pi.on("tool_call", async (event) => {
  if (event.type !== "tool_call" || event.toolName !== "bash") return {};
  const command = String(event.input?.command ?? "");
  const cdResult = await runCdCheck(command);              // bin/syn-cd-pretool-check.sh
  if (cdResult.code === 2) return { block: true, reason: cdResult.stderr.trim() || "..." };
  const result = await runPretoolCheck(command);           // bin/syn-arm-pretool-check.sh
  if (result.code !== 2) return {};
  return { block: true, reason: result.stderr.trim() || "..." };
});
```

Both seatbelts piggyback on the same extension file so no extra `-e` flag is needed at launch.

---

## 3. The Vörðr digest supervisor

`.pi/extensions/lib/vordr-sessionstart-supervisor.mjs` runs the Sága runner as a **detached child** so Pi can stream and cap output without blocking the session open.

Sýn spawns it (`.pi/extensions/syn-turnend-guard.ts:260-282`):

```ts
const supervised = process.platform !== "win32";
const runner = `${root}/bin/saga-sessionstart-run.sh`;
child = spawn(
  supervised ? "node" : runner,
  supervised
    ? [`${extensionDir}/lib/vordr-sessionstart-supervisor.mjs`, runner, "--source", generation.source, "--pi-prerequisite"]
    : ["--source", generation.source, "--pi-prerequisite"],
  {
    detached: supervised,
    env: { ...process.env, BROKK_SESSION_PID: String(process.pid) },
    stdio: supervised ? ["ignore", "pipe", "ignore", "ipc"] : ["ignore", "pipe", "ignore"],
  },
);
```

Vörðr's contract (`.pi/extensions/lib/vordr-sessionstart-supervisor.mjs`):

- `process.argv.slice(2)` = `[runner, ...args]`.
- Spawns the runner with `env.VORDR_SESSIONSTART_SUPERVISOR_PID`.
- Streams child stdout to its own stdout and counts `outputBytes`.
- Sends `{ type: "result", code, bytes }` over IPC once writes drain.
- On `disconnect` (parent died) it `process.kill(-process.pid, "SIGKILL")` to reap the group.

Sýn therefore treats the **result message** as the completion signal, not the `close` event (which can arrive early). This is why `completePending` waits until `observedBytes >= result.bytes` before settling.

### `BROKK_SESSION_PID` lock binding

The digest child is launched with `env.BROKK_SESSION_PID = String(process.pid)` — the **live Pi process**. `bin/gleipnir-lock-lib.sh` writes that pid to `state/.lock` (`gleipnir_lock_acquire`, `bin/gleipnir-lock-lib.sh:65-76`), so the lock survives the short-lived digest helper. Both Sýn and Gná verify ownership by walking `ps -o ppid=` ancestry up to 8 levels and comparing to the `.lock` pid (`lockOwnership()` in both files). `other` means read-only; `missing` means the lock is gone/stale.

### Delivery cap and truncation

Sýn caps injected bytes at `sessionstartDeliveryBytes = 512 * 1024` (`.pi/extensions/syn-turnend-guard.ts:71`). On overflow it appends:

```
PI SESSION-START DELIVERY TRUNCATED - the digest exceeded 512 KiB. Treat omitted context as unread and inspect the named files directly before acting on it.
```

On a failed/empty startup it substitutes the manual fallback:

```
Run `bin/saga-session-start.sh` now, exactly once, before executing any other instructions.
```

Pi's prerequisite exit is `sessionstartIneligibleExit = 3`; a stand-down (`BROKK_SESSIONSTART_INELIGIBLE=1`) exits 3 and is mapped to `{ kind: "ineligible" }` rather than `failed`.

---

## 4. Gná watcher continuity

`.pi/extensions/gna-pi-watch.ts` owns the watcher in the persistent TUI. It exposes:

- **Command** `pi.registerCommand("gna-watch-arm", ...)` (line 530).
- **Tool** `pi.registerTool({ name: "gna_watch_arm", ... })` (line 538) with `promptGuidelines` telling the model to call it **only** for the first cycle or after an actionable notification, never after ordinary work — the extension re-arms automatically.
- **Events** `session_start` (activate generation, `markLoaded`) and `session_shutdown` (stop generation).

Arm spawn (`.pi/extensions/gna-pi-watch.ts:397-434`):

```ts
const ownership = lockOwnership();
if (ownership === "other")  return { ok:false, message:"watcher: read-only - session lock is held by another Brokk session" };
if (ownership === "missing") return { ok:false, message:"watcher: not armed - no live session holds the lock; run bin/saga-session-start.sh ..." };
const env = { ...process.env, BROKK_HOME, BROKK_ROOT_OVERRIDE, BROKK_CONFIG_OVERRIDE,
              BROKK_WATCH_ARM_SCRIPT, BROKK_WATCH_PREDECESSOR_ARM_PID, BROKK_SESSION_PID: String(process.pid) };
const armChild = spawn("bash", ["-lc", 'exec "$BROKK_WATCH_ARM_SCRIPT" --restart'], { cwd: brokkRoot, env, ... });
```

Continuity: `classifyClose` separates **actionable** (`signal:`/`stale:`/`check:`/`heartbeat:` line) from **failure**. Actionable → `restoreAfterActionableClose` (retries with backoff) then `deliverActionableWake` (encodes a `watcher` Rödd message and `pi.sendUserMessage(..., {deliverAs:"followUp"})`). Failure → `scheduleRetry`. Retry knobs: `BROKK_WATCH_REARM_RETRY_BASE_MS` (250), `..._MAX_MS` (4000), `..._LIMIT` (5); readiness `BROKK_PI_ARM_READY_TIMEOUT_MS` (12s, 35s on win32); retire `BROKK_WATCH_ARM_RETIRE_TIMEOUT_MS` (1000).

On an actionable close, Gná calls `bin/syn-watch-arm.sh --handling-delivered <generation> --watcher-pid <pid>` to acknowledge handling; the script prints `watcher: handling delivered ...` and exits 0 (`bin/syn-watch-arm.sh:26-31`).

Loaded markers written by the extensions (skipped while lock is `other`):

| Marker | Written by |
|---|---|
| `state/.pi-syn-turnend-loaded` | Sýn `markLoaded()` |
| `state/.pi-gna-watch-loaded` | Gná `markLoaded()` |

Content is `<extensionVersion sha256>\n<pid>\n`.

---

## 5. Trust

Pi will not auto-load tracked `.pi/extensions/*.ts` until the project is trusted. **Approve the project trust prompt once per clone on first launch.** If trust is not approved, the extensions never load and the session is unseated.

Upstream's trust-free fallback is to launch the selected executable with the extension flags explicitly:

```bash
pi -e .pi/extensions/syn-turnend-guard.ts -e .pi/extensions/gna-pi-watch.ts
```

Use this only for diagnosis or an untrusted checkout; the production path is the trust prompt.

---

## 6. Install / enable / verify

### Enable

Extension files must be present under `.pi/extensions/`. Signing/selection is a Pi-side concern (`BROKK_PI_HARNESS=pi-signed` selects the `pi-signed` identity in `bin/hamr-harness.sh`).

### Verify loading

```bash
cd "$BROKK_HOME"
# Markers are written on extension load (and session_start for Sýn).
test -f state/.pi-syn-turnend-loaded && echo "Sýn loaded: $(head -n1 state/.pi-syn-turnend-loaded)"
test -f state/.pi-gna-watch-loaded   && echo "Gná loaded: $(head -n1 state/.pi-gna-watch-loaded)"
```

### Verify the digest before the first turn

```bash
# What Sýn runs under Vörðr:
node .pi/extensions/lib/vordr-sessionstart-supervisor.mjs bin/saga-sessionstart-run.sh --source startup --pi-prerequisite | head -n 20
echo "exit=$?"   # wrapper exits 0; Vörðr reports {type:"result",code,bytes}
# Direct wrapper for comparison:
bin/saga-sessionstart-run.sh --source startup --pi-prerequisite | head -n 5
```

### Verify the turn-end guard

```bash
rm -f state/.supervision-armed
echo '{"stop_hook_active":false}' | bin/syn-turnend-guard.sh; echo "inert -> $? (expect 0)"
touch state/.supervision-armed; rm -f state/.watch.heartbeat
echo '{"stop_hook_active":false}' | bin/syn-turnend-guard.sh; echo "armed+stale -> $? (expect 2)"
```

### Verify the seatbelts as `tool_call` would

```bash
bin/syn-cd-pretool-check.sh  --command 'cd ../../etc';            echo "cd -> $? (expect 2)"
bin/syn-arm-pretool-check.sh --command 'bin/syn-watch-arm.sh &';  echo "arm -> $? (expect 2)"
```

### Verify Gná's arm tool path

```bash
# With a live lock owned by this process tree:
bash -lc 'BROKK_SESSION_PID=$$ exec bin/syn-watch-arm.sh --restart' &
sleep 1; test -s state/.watch.heartbeat && echo "heartbeat ok"
bin/syn-watch-arm.sh --handling-delivered test-gen --watcher-pid 12345
```

---

## 7. Gotchas

- **Gná is Pi-only.** OpenCode's watcher is **Sýn** (`.opencode/plugins/syn-watch-arm.js`). Do not look for `gna-*` in `.opencode/`.
- **Neither extension is inert by accident.** Sýn's guard is inert until `state/.supervision-armed` exists; arm first, then test.
- **`supervised` only on non-Windows.** On Windows Sýn runs the runner directly with no Vörðr and no IPC; completion comes from the `close` event. Do not assume the IPC result path exists cross-platform.
- **Vörðr kills its process group on disconnect.** If Pi dies, the digest child is SIGKILLed. A lingering `VORDR_SESSIONSTART_SUPERVISOR_PID` means the reap failed.
- **The digest is capped at 512 KiB.** A large digest is truncated with an explicit marker; treat omitted context as unread.
- **`session_compact` bypasses `before_agent_start`.** The compact handler calls `pi.sendMessage` directly; if you refactor delivery, keep both paths.
- **`guardFollowupActive` is module-global.** It assumes one guard cycle at a time; concurrent settles can drop one due to the boolean.
- **`markLoaded()` refuses while the lock is `other`.** A read-only Pi session will not write markers, so absence of a marker alone does not prove the extension failed to load.
- **Tool event filtering is `event.toolName === "bash"`.** A renamed shell tool disables both seatbelts silently.
- **Trust is per clone.** A fresh clone or a copied home that never approved the prompt has no loaded extensions. Restart with explicit `-e` flags only to diagnose.
- **`.pi/extensions/README.md:36-38` is stale.** It claims "the `.opencode` plugins and Claude/Grok/Codex/Cursor/adapters … are still to come." They are landed; see [`opencode.md`](opencode.md), [`claude-code.md`](claude-code.md), [`codex.md`](codex.md), [`cursor.md`](cursor.md). Grok remains unimplemented in Ymir.
- **`vordr` and `rodd` use different extensions** (`.mjs` vs `.ts`) deliberately: Vörðr is a plain Node child, so it cannot import the Pi TypeScript lib.

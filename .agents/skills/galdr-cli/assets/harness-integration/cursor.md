# Cursor Harness Adapter

> **Purpose:** Rebuild, verify, or extend the Cursor adapter — the `.cursor/hooks.json` project hooks that inject the Sága digest via `additional_context`, emit a turn-end `followup_message`, and run the PreToolUse seatbelts.

Cursor is a **run-tier session-open** harness (it injects `additional_context`) and a **turn-end-only** harness (the `stop` hook returns a `followup_message`; there is no long-lived arm child). Cursor is not an Eindri dispatch target in Ymir, but it is a wired Brokk surface.

---

## 1. Files

| File | Contract parts |
|---|---|
| `.cursor/hooks.json` | Session-open injection + turn-end guard + PreToolUse seatbelts |

The adapter is pure hook JSON. There is no plugin runtime and no `.cursor/rules/` dependency.

---

## 2. The hook file (verbatim)

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      {
        "type": "command",
        "command": "digest=$(\"$CURSOR_PROJECT_DIR\"/bin/saga-sessionstart-run.sh --source startup </dev/null 2>/dev/null); [ -n \"$digest\" ] || exit 0; command -v jq >/dev/null 2>&1 || exit 0; jq -n --arg c \"$digest\" '{additional_context:$c}' 2>/dev/null || true",
        "timeout": 180
      }
    ],
    "stop": [
      {
        "type": "command",
        "command": "guard=$(\"$CURSOR_PROJECT_DIR\"/bin/syn-turnend-guard.sh 2>&1 </dev/null); rc=$?; [ \"$rc\" -eq 2 ] || exit 0; command -v jq >/dev/null 2>&1 || exit 0; jq -n --arg m \"$guard\" '{followup_message:$m}' 2>/dev/null || true",
        "timeout": 30
      }
    ],
    "preToolUse": [
      {
        "matcher": "Shell",
        "type": "command",
        "command": "\"$CURSOR_PROJECT_DIR\"/bin/syn-arm-pretool-check.sh --cursor",
        "timeout": 10
      },
      {
        "matcher": "Shell",
        "type": "command",
        "command": "\"$CURSOR_PROJECT_DIR\"/bin/syn-cd-pretool-check.sh --cursor",
        "timeout": 10
      }
    ]
  }
}
```

`.cursor/hooks.json` is 33 lines. `"version": 1` is Cursor's hook schema version and is required.

---

## 3. `sessionStart` — run-tier injection

```bash
digest=$("$CURSOR_PROJECT_DIR"/bin/saga-sessionstart-run.sh --source startup </dev/null 2>/dev/null)
[ -n "$digest" ] || exit 0                  # no digest → no-op
command -v jq >/dev/null 2>&1 || exit 0     # jq is required to shape JSON
jq -n --arg c "$digest" '{additional_context:$c}' 2>/dev/null || true
```

- **Root** comes from `$CURSOR_PROJECT_DIR`.
- **Source is explicit** (`--source startup`): unlike Claude/Codex, Cursor does not deliver a source-bearing JSON payload here.
- **stdin is closed** (`</dev/null`) so the wrapper never blocks on a read.
- **Output shape:** `{"additional_context": "<digest>"}`. Cursor injects that string as session context. This is the run-tier injection.
- **`|| true`** means a `jq` failure degrades to no context rather than a failed hook. `jq` is a hard dependency for Cursor; without it the whole adapter no-ops.
- `timeout: 180`.

Cursor also loads the tracked Claude settings, so upstream guards against double-running. Ymir's `.cursor/hooks.json` passes an explicit `--source` and does **not** pipe a payload, so the wrapper does not run the foreign-host detection.

---

## 4. `stop` — turn-end guard

```bash
guard=$("$CURSOR_PROJECT_DIR"/bin/syn-turnend-guard.sh 2>&1 </dev/null); rc=$?
[ "$rc" -eq 2 ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
jq -n --arg m "$guard" '{followup_message:$m}' 2>/dev/null || true
```

- Runs the guard with **stderr merged into stdout** (`2>&1`), so the recovery text is captured.
- Only exit **2** produces output; all other exits are silent (`exit 0`).
- **Output shape:** `{"followup_message": "<guard text>"}`. Cursor posts that message as a follow-up to the session, which is how the blind-turn-end refusal reaches the model.
- `timeout: 30`.

There is **no re-arm** hook: Cursor has no async/background Stop continuation in this adapter. Supervision is expected to be owned elsewhere (or the session runs with the guard inert until an arm exists). Treat Cursor as the weakest supervision surface.

---

## 5. `preToolUse` — seatbelts

Two entries, both `"matcher": "Shell"`:

```bash
"$CURSOR_PROJECT_DIR"/bin/syn-arm-pretool-check.sh --cursor   # timeout 10
"$CURSOR_PROJECT_DIR"/bin/syn-cd-pretool-check.sh  --cursor   # timeout 10
```

- `--cursor` selects Cursor's transport semantics in the owner scripts.
- Exit **2** blocks the shell call; the reason is on stderr.
- `syn-arm-pretool-check.sh` denies a command that backgrounds `syn-watch-arm.sh`; `syn-cd-pretool-check.sh` denies `cd .../../`.
- Both are inert-by-default contracts: they allow everything else.

---

## 6. Trust

Cursor project hooks require the workspace to be launched with **`--trust`**. Without it, none of the project hooks load and Brokk is never seated.

```bash
cursor-agent --trust
```

Upstream Brokk also notes a hard limit worth carrying into Ymir: **headless `cursor-agent -p` has no turn-end hook**, so a Cursor primary must be run **interactively** for supervision to work. If Cursor is driven headlessly, only `sessionStart` and `preToolUse` fire.

---

## 7. Install / enable / verify

### Enable

`.cursor/hooks.json` is tracked and project-local. Cursor reads it when the workspace is trusted. The runtime scripts must exist under `$CURSOR_PROJECT_DIR/bin/`. `jq` must be installed.

### Syntax / schema

```bash
cd "$BROKK_HOME"
python3 -m json.tool .cursor/hooks.json >/dev/null && echo "cursor hooks JSON ok"
command -v jq >/dev/null && echo "jq present" || echo "jq MISSING - adapter will no-op"
```

### Verify sessionStart output shape

```bash
digest=$("$BROKK_HOME/bin/saga-sessionstart-run.sh" --source startup </dev/null 2>/dev/null)
echo "digest bytes: ${#digest}"
jq -n --arg c "$digest" '{additional_context:$c}' | jq -e 'has("additional_context")' && echo "shape ok"
```

### Verify stop output shape

```bash
# Inert guard:
rm -f state/.supervision-armed
guard=$(bin/syn-turnend-guard.sh 2>&1 </dev/null); rc=$?
echo "rc=$rc (expect 0; no followup_message emitted)"

# Armed + stale → emit followup_message:
touch state/.supervision-armed; rm -f state/.watch.heartbeat
guard=$(bin/syn-turnend-guard.sh 2>&1 </dev/null); rc=$?
echo "rc=$rc (expect 2)"
[ "$rc" -eq 2 ] && jq -n --arg m "$guard" '{followup_message:$m}' | jq -e 'has("followup_message")' && echo "shape ok"
```

### Verify preToolUse

```bash
bin/syn-arm-pretool-check.sh --cursor --command 'bin/syn-watch-arm.sh &'; echo "arm -> $? (expect 2)"
bin/syn-cd-pretool-check.sh  --cursor --command 'cd ../..';             echo "cd  -> $? (expect 2)"
```

> Note: `--command` and `--cursor` are both parsed by the owner scripts; the hook commands above pass only `--cursor` because in the real hook the command text arrives on stdin. For a local smoke test, pass `--command` explicitly.

---

## 8. Gotchas

- **`--trust` is mandatory.** No trust → no hooks → no Brokk.
- **`jq` is a hard dependency.** Both `sessionStart` and `stop` shape JSON with `jq` and exit 0 if it is missing. A missing `jq` silently disables injection and the guard.
- **Headless Cursor has no turn-end hook.** `cursor-agent -p` fires only `sessionStart`/`preToolUse`; run interactively for supervision.
- **`stop` is guard-only; there is no arm.** `syn-turnend-guard.sh` is inert until something else arms supervision. With no arm on Cursor, the guard's exit 2 only occurs if an arm exists from another source. Do not claim Cursor has turn-end supervision until an arm path is verified.
- **stderr is merged into stdout in `stop`.** Do not "clean up" `2>&1`; the guard's recovery text lives on stderr.
- **Explicit `--source startup` means resume/compact are not differentiated.** Cursor always takes the full digest at session open. Acceptable (redundant but cheap), but it means a resumed Cursor session re-runs the digest rather than nudging.
- **`|| true` hides `jq` failures.** A malformed digest cannot fail the hook; it just produces no context. Diagnose by running the two commands by hand.
- **`matcher: "Shell"` is exact.** If Cursor renames the shell tool, both seatbelts stop firing.
- **PreToolUse timeout is 10s.** A slow `bin/syn-*-pretool-check.sh` call can time out and allow the command; keep the owner scripts fast (they are pure `case` matches).

---

## 9. Code-vs-doc note

Plan 29 §7 describes Cursor as "run interactive only (no headless turn-end)". The code matches that limitation, but it **also** implements a `sessionStart` `additional_context` injection and a `stop` `followup_message`. So Cursor is a full session-open + turn-end surface interactively — not merely a runner.

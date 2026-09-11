# Claude Code Harness Adapter

> **Purpose:** Rebuild, verify, or extend the Claude Code adapter — the `.claude/settings.json` `SessionStart` and `Stop` hooks that run the Sága digest at session open and re-arm **Sýn** + guard the turn end at Stop.

Claude Code is a **run-tier** harness: `SessionStart` hook stdout is injected into the session context, so the digest is seated before the model acts. Claude is **not** an Eindri dispatch target in Ymir (the verified launch set is `opencode pi pi-signed`), but it is a fully wired Brokk surface.

---

## 1. Files

| File | Contract parts |
|---|---|
| `.claude/settings.json` | Session-open injection + turn-end guard + re-arm |

There is **no** PreToolUse seatbelt in Ymir's `.claude/settings.json` (upstream Brokk has them; see §7). There is no `.claude/hooks/` directory and no plugin runtime — Claude's adapter is pure hook JSON.

---

## 2. The hook file (verbatim)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[ -z \"${GROK_AGENT:-}${GROK_HOOK_EVENT:-}\" ] || exit 0; exec \"$CLAUDE_PROJECT_DIR\"/bin/saga-sessionstart-run.sh",
            "timeout": 180
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[ -z \"${GROK_AGENT:-}${GROK_HOOK_EVENT:-}\" ] || exit 0; exec \"$CLAUDE_PROJECT_DIR\"/bin/syn-turnend-guard.sh --claude"
          },
          {
            "type": "command",
            "command": "[ -z \"${GROK_AGENT:-}${GROK_HOOK_EVENT:-}\" ] || exit 0; out=$(exec \"$CLAUDE_PROJECT_DIR\"/bin/syn-watch-arm.sh --restart); rc=$?; case \"$out\" in *signal:*|*stale:*|*check:*|*heartbeat:*) printf '%s\n' \"$out\" >&2; exit 2;; esac; exit $rc",
            "asyncRewake": true,
            "timeout": 28800
          }
        ]
      }
    ]
  }
}
```

`.claude/settings.json` is 31 lines; the entire adapter is these two hook groups.

---

## 3. SessionStart — run-tier injection

### Command anatomy

```bash
[ -z "${GROK_AGENT:-}${GROK_HOOK_EVENT:-}" ] || exit 0     # (1) skip when a Grok hook process reuses Claude settings
exec "$CLAUDE_PROJECT_DIR"/bin/saga-sessionstart-run.sh    # (2) run the wrapper; stdout is injected
```

1. **The Grok guard.** Claude Code is Claude-compatible and Grok reuses `.claude/settings.json`; a Grok hook process carries `GROK_AGENT` or `GROK_HOOK_EVENT`. If either is set, the hook exits 0 without running, so the digest is not taken twice. (Grok's own adapter is not implemented in Ymir, but this guard is retained from the upstream pattern and is harmless.)
2. **`$CLAUDE_PROJECT_DIR`** is Claude's project root env var; the runtime root is derived from it directly, not from `pwd`. The runtime must be at `$CLAUDE_PROJECT_DIR/bin/`.
3. **`exec`** replaces the shell so the hook's exit status is the wrapper's. `timeout: 180` seconds.

### Run vs nudge on this hook

The wrapper is run-tier here, but it still routes internally:

| `source` (from hook stdin JSON) | Wrapper behavior |
|---|---|
| `startup`, `new` | run `bin/saga-session-start.sh`; write `state/.session-start-complete` |
| `clear`, `compact` | if already complete, print a short `CONTEXT RE-EMIT` note; else run the full digest |
| `resume`, `reload`, `fork` | print the nudge line: `Run \`bash .../bin/saga-session-start.sh\` exactly once now ...` |

Claude sends a JSON payload on stdin shaped like `{"source":"startup",...}`; `bin/saga-sessionstart-run.sh` parses it without `jq` (`bin/saga-sessionstart-run.sh:34-44`). If `source` is absent or unrecognized it defaults to `startup` — taking the helm redundantly is cheap; not taking it is the bug.

> **Exit-code law.** Claude's `SessionStart` hook exit 2 blocks session initialization. The wrapper therefore **always exits 0 on the transport path** (`bin/saga-sessionstart-run.sh` header comment). A failed session start must arrive as digest text the agent can act on, never as a refusal to open. Do not add a hook that can fail the open.

---

## 4. Stop — turn-end guard + re-arm

Stop runs **two independent commands**, in order.

### 4.1 Turn-end guard

```bash
[ -z "${GROK_AGENT:-}${GROK_HOOK_EVENT:-}" ] || exit 0
exec "$CLAUDE_PROJECT_DIR"/bin/syn-turnend-guard.sh --claude
```

- `--claude` is a compatibility tag. The current guard has **no argument parsing**, so it is ignored; do not rely on it changing behavior. (The peer `--cursor` tags *are* parsed by the seatbelt scripts, which ignore them via a `*)` branch.)
- stdin receives `{"stop_hook_active":false}`, which the guard drains (`cat >/dev/null`).
- **exit 0** when supervision is healthy or was never armed.
- **exit 2** when supervision was armed and the watcher is missing/stale; stderr carries:
  ```
  Brokk supervision is off: the watcher cycle is missing, failed, or unhealthy.
  Recovery: re-arm through the harness extension (gna_watch_arm). Do not end the turn blind.
  ```
  Claude surfaces the stderr and re-prompts instead of ending the turn.

### 4.2 Async re-arm

```bash
out=$(exec "$CLAUDE_PROJECT_DIR"/bin/syn-watch-arm.sh --restart); rc=$?
case "$out" in *signal:*|*stale:*|*check:*|*heartbeat:*) printf '%s\n' "$out" >&2; exit 2;; esac
exit $rc
```

- `"asyncRewake": true`, `"timeout": 28800` (8 hours) keeps the arm running out of band at the end of a turn — this is Claude's continuity mechanism in lieu of a plugin-owned child.
- Any actionable line (`signal:` / `stale:` / `check:` / `heartbeat:`) is printed to stderr and forces exit 2, which rewakes the session.
- Otherwise the arm's own exit code is passed through.

### Why two Stop hooks

The guard answers "is supervision healthy right now?"; the arm answers "keep it healthy". They are separate commands so a healthy guard never blocks the re-arm, and an actionable arm always forces a rewake even if the guard's heartbeat window still looked fresh.

---

## 5. Install / enable / verify

### Enable

`.claude/settings.json` is tracked and project-local; Claude Code reads it automatically. No symlink or registration is needed. The runtime scripts it calls must exist under `$CLAUDE_PROJECT_DIR/bin/`.

### Syntax / schema

```bash
cd "$BROKK_HOME"
python3 -m json.tool .claude/settings.json >/dev/null && echo "claude settings JSON ok"
```

### Verify SessionStart exactly as the hook runs

```bash
printf '{"source":"startup"}' | "$BROKK_HOME/bin/saga-sessionstart-run.sh" | head -n 20
printf '{"source":"startup"}' | "$BROKK_HOME/bin/saga-sessionstart-run.sh" >/dev/null; echo "exit=$? (must be 0)"
printf '{"source":"resume"}' | "$BROKK_HOME/bin/saga-sessionstart-run.sh" | head -n 2
# expected: Run `bash .../bin/saga-session-start.sh` exactly once now ...
```

### Verify Stop

```bash
# Guard, inert:
rm -f state/.supervision-armed
echo '{"stop_hook_active":false}' | bin/syn-turnend-guard.sh --claude; echo "inert -> $? (expect 0)"
# Guard, armed + stale:
touch state/.supervision-armed; rm -f state/.watch.heartbeat
echo '{"stop_hook_active":false}' | bin/syn-turnend-guard.sh --claude; echo "armed+stale -> $? (expect 2)"

# Re-arm command body, emulated (must own the lock):
state=$(mktemp -d)
out=$(BROKK_STATE_OVERRIDE="$state" BROKK_HOME="$BROKK_HOME" bin/syn-watch-arm.sh --restart); rc=$?
case "$out" in *signal:*|*stale:*|*check:*|*heartbeat:*) echo "would rewake";; esac
echo "arm rc=$rc"
```

### Verify the Grok guard

```bash
# With a Grok marker set, both hooks must no-op with exit 0.
GROK_AGENT=1 bash -c '[ -z "${GROK_AGENT:-}${GROK_HOOK_EVENT:-}" ] || exit 0; echo "skipped"'
```

---

## 6. Gotchas

- **Do not let SessionStart exit non-zero.** Exit 2 blocks Claude session initialization. The wrapper is designed to always exit 0; a hook that wraps it must preserve that.
- **`$CLAUDE_PROJECT_DIR` must point at the runtime root.** Ymir's scripts are rooted at `$CLAUDE_PROJECT_DIR/bin`; if the runtime is installed elsewhere, set the env var or the hooks no-op/err.
- **The Grok guard is load-bearing, not cosmetic.** Claude-compatible harnesses (Grok) reuse `.claude/settings.json`; without the `GROK_AGENT`/`GROK_HOOK_EVENT` guard the digest would run twice.
- **`asyncRewake` re-arm is the only continuity on Claude.** There is no long-lived plugin child; if the Stop hook is removed or its timeout shortened, supervision dies at the first turn end.
- **No PreToolUse seatbelts here.** Ymir's `.claude/settings.json` omits the arm/cd PreToolUse entries that upstream Brokk ships. A model bash call that backgrounds `syn-watch-arm.sh` is therefore not blocked on Claude. Treat this as a known gap (§7) and rely on the guard, not the seatbelt.
- **The Stop guard and re-arm are independent.** Removing one silently degrades supervision: no guard → blind turn ends; no arm → immediate stale heartbeat.
- **stdin is consumed.** Hook commands receive JSON on stdin; any wrapper you add must not block reading it. The guard drains stdin itself.
- **`timeout: 28800` is deliberate.** Shortening the Stop arm timeout causes it to be killed mid-session and the guard to report stale on the next turn.

---

## 7. Known gaps (code-vs-doc)

| Plan 29 §7 says | Ymir `.claude/settings.json` truth |
|---|---|
| Claude Code is `SessionStart` + `Stop` | correct — those are the only two hook groups present |
| (implicit: same four contract parts as other harnesses) | **no `PreToolUse`** arm/cd seatbelts are registered |

Upstream Brokk registers two `PreToolUse` entries (`Bash` matcher → `fm-arm-pretool-check.sh --claude`, `fm-cd-pretool-check.sh --claude`). To close the gap, add the equivalent `PreToolUse` block calling `bin/syn-arm-pretool-check.sh --claude` and `bin/syn-cd-pretool-check.sh --claude`. Do not assume the seatbelt is active until it is added and smoke-tested.

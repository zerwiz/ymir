## sessrumnir · unversioned · 2026-11-09 — a message typed while the agent works waits its turn

### Why
- **The composer interrupted instead of queueing.** `store.ts`'s `sendPrompt` sent every message typed
  during streaming through `commands.steer`, and Pi defines steering as entering *after the current
  assistant turn and its tool calls* — an interruption of the running work, not a message that waits.
  Pi's own queueing command, `follow_up`, was already wired (`PI_FOLLOW_UP` → `{ type: 'follow_up' }`)
  and documented as *"waits for agent to finish all tools"*, but nothing in the GUI ever called it on a
  plain send; the status bar even rendered a `pendingFollowUp` badge for a queue nothing filled.
- **`followUp` could not carry images.** `bridge.ts`, `bridge-http.ts`, `preload/index.ts` and the
  `PI_FOLLOW_UP` handler all passed the message alone, while `steer` accepted `PromptImage[]` — which is
  the likely reason steering became the default. A queued message would have lost its screenshot.
- **There was no separate gesture for interrupting.** The window-level Enter handler checked only
  `!e.shiftKey`, so Ctrl/Cmd/Alt+Enter were indistinguishable from Enter.

### What changed
- `store.ts` `sendPrompt`: while streaming, the message is sent as a **follow-up** (queued), with images;
  a plain send when idle is still a prompt. `sendFollowUp` and `sendSteer` now both accept `PromptImage[]`.
- `preload/index.ts`, `shared/bridge-http.ts`, `shared/bridge.ts` and `main/ipc/pi-handlers.ts` thread
  `images` through `pi:follow-up` exactly as `pi:steer` already did.
- `hooks.ts` `useChatKeyboard` gains an optional `onInterrupt`: **Ctrl/Cmd+Enter or Alt+Enter** steers into
  the running turn on purpose (Alt+Enter is Pi's own `app.message.followUp` neighbour in its TUI), while
  Enter keeps sending — now queued.
- `chat-input.tsx` builds the outbound prompt once (`buildOutbound`) so `handleSend` and the new
  `handleInterrupt` share attachment handling, and the streaming placeholder says what happens:
  `chat.composer.placeholderQueued` — *"Message queues after this turn — Ctrl/⌘+Enter or Alt+Enter
  interrupts now"*.

### Proof
- `npx tsx --test src/renderer/src/store-external-prompts.test.ts` → **13 passed**, including four new
  cases: a streaming send calls `followUp` and never `steer`; an idle send still prompts; images ride
  along with a queued follow-up; `sendSteer` still steers with images.
- `tsc -b --noEmit` reports nothing in the touched files. The one remaining `bridge-http.ts(336)` `fleet`
  error is pre-existing and unrelated (it is not in this diff), and full lint/type resolution needs the
  workspace `node_modules`, which a fresh worktree does not carry.

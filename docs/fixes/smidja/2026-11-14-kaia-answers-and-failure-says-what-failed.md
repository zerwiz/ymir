# smidja · 2026-11-14 — Kaia answers, and a failure says what actually failed

**Component:** smidja · **Branch:** `eindri/smidja-header-chat` (plan 275, item 15)
**Files:** `apps/smidja-factory/apps/visualizer/server/chat.ts`, `server/kaia.test.ts`

## Why

The Allfather, plan 275 §02:50: *"why are smidja even talking about excalidraw?? what backend are
we using"*. Every chat message returned 500 with a message built from pi's **extension status
lines** — `[constellation] mesh: unconfigured`, `[excalidraw] excalidraw: no fork` — and the real
provider error was cut at 300 characters, leaving `400: {"type":"se`.

## The cause, measured

Run by hand, exactly as the server runs it, from the chat's repo root:

```
$ pi --print --session chat/repro-a --model opencode-go/deepseek-v4-flash "say hello"
Warning: Model "deepseek-v4-flash" not found for provider "opencode-go". Using custom model id.
[constellation] mesh: unconfigured — …
[excalidraw] excalidraw: no fork — …
400: {"type":"server_error","message":"Upstream request failed: Model is unavailable."}
rc=1
```

So pi exits 1 because the default model id is not one this machine serves: `bin/model/catalog.sh
--has opencode-go/deepseek-v4-flash` answers **NOT IN THE CATALOG**, while
`opencode-go/deepseek-v4.1-flash` is listed and answers on the same command in 4 seconds (`rc=0`).

## What changed

1. **The default model is the house's**: `opencode-go/deepseek-v4.1-flash`
   (`DEFAULT_CHAT_MODEL`, exported so a test can pin it).
2. **The real error is shown whole.** `failureReason()` drops every `[<extension>]` status line
   and joins what is left with no truncation — pi's own warning stays, because it names the model.
   If nothing but status lines came back, it repeats them rather than saying nothing.
3. **The persona paths are current.** `kaiaPromptArgs()` looked in
   `apps/smidja/…` and `.agents/skills/smidja/…`, neither of which exists since the app moved
   under `apps/smidja-factory/`; the two real paths are added ahead of them (the old ones kept).

## Proof

In the real window (private Electron, DevTools on 9444, this worktree's `dist`, server on `:8537`),
a message typed into Kaia's own input and sent through the UI:

```
+33s  rows 2  streaming false  errors []  model null
FINAL text: "I am Hœnir, your counsellor seated here on heimdall — and the smithy, Smíðja, is
the forge where worker agents are built from new work, rostered into teams, and sent out to do
the making."
```

The failure path, through the same endpoint the UI calls, with the old bad id:

```
Völundr (Pi) failed (exit 1) — Warning: Model "deepseek-v4-flash" not found for provider
"opencode-go". Using custom model id.
400: {"type":"server_error","message":"Upstream request failed: Model is unavailable."}
```

No `[constellation]`, no `[excalidraw]`, nothing cut. `bun test`: 14 pass, 0 fail (5 new tests
pin the filter, the whole error, pi's warning, the empty case, and the default id).

## Not done, named — and it is the important one

**The chat still answers in the seat's voice, not Völundr's.** The target repo here is
`~/Documents/ymirhome` (the service's `CMD_DB` is `$YMIR_HOME/smidja/smidja.db`),
and that tree holds neither persona file, so no `--append-system-prompt` is passed and pi answers
from the home contract in its working directory. Measured above: the reply introduced itself as
the seat's counsellor. The one-line fix is to let `kaiaPromptArgs()` also resolve the persona from
the **app's own tree** (the visualizer ships inside the repo that holds
`apps/smidja-factory/skills/volundr/prompt/volundr-system.md`), but that changes what the chat
*is* — a worker entity, not a chat assistant — and plan 275's own law says behaviour beyond the
fix earns its own proof. It is recorded for the helm rather than slipped in here.

## CHANGE LOG

- 2026-11-14 — failure text rebuilt from the real cause; extension status lines dropped; default
  model corrected to `opencode-go/deepseek-v4.1-flash`; persona paths brought current; five tests.

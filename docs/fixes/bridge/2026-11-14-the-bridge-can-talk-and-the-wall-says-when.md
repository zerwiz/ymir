# The bridge can talk, and the wall says when

**Component:** `bridge` (the whiteboard's AI bridge) · **Date:** 2026-11-14 · **Tickets:**
`feature-0037`, `feature-0038` (server half) · **Contract:** plan 158 §appended, and plan 233 §16.

## Why

His words: *"can a user chat with the modell before its making the flowcharst to fiure out whats
the best way do to the thing the user needs."* The answer was no, and the reason was a transport
rule rather than a model limit: the bridge's system prompt says *"Reply with the Mermaid source
ONLY"*, because the panel parses the reply as a diagram and prints *"Mermaid syntax error"* for
anything else. A helpful sentence — "here are two ways to model this" — was rendered as a failure.

Then his second word: *"it need to be able to talk. can we have some tools for it to be able to
use the whitebord better?"* — and his third, which is the boundary: *"it should only have tools
inside whitebord."*

## What changed

**Two modes, one rail.** `POST /v1/ai/converse/chat-streaming` is new: plain conversation, the
same upstream, a system prompt that asks before it draws. The rule the ticket is built on is in
the prompt as a hard number — when the request is ambiguous, ask **at most two** questions and
wait. Two, because a wall of questions is an interrogation, not a conversation.

**`generate` is untouched.** Same prompt, same fence filter, same bare Mermaid, and — this is the
part that matters — it is never offered a single tool, so a regression there is impossible by
construction rather than by care.

**Seven tools, and the boundary that keeps it at seven.** `tools.mjs` holds exactly what a person
can already do from the whiteboard's own menus: `read_canvas`, `add_elements`, `update_elements`
(only ids the same turn created — the person's own strokes are immutable), `validate_diagram`,
`focus`, `save_room`, `share_room`. There is no second tier and no deferred decision: no record
lookup, no web search, no mail, no ledger. A client may *narrow* that surface and may never widen
it.

**The wall is shown.** A metered rail answering `429` used to reach the panel as
`Upstream returned 429: {...}` and render as a bare "error" — indistinguishable from a broken
board. `usage-limit.mjs` reads the reset time from the response's headers, or from the rail's own
words when there is no header, and returns one sentence: *"The model's usage limit is reached. It
resets in 2 hours 15 minutes (at 02:40) — ask again after that."* When the rail does not say, the
sentence says that too, rather than inventing a time.

## Verified

```
node systems/whiteboard/services/ttd-bridge/test/prove-live.mjs
  converse reply            questions=2 mermaid=false
  the request carried      tool_choice=auto tools=7 [read_canvas,add_elements,update_elements,validate_diagram,focus,save_room,share_room]
  generate reply            fenced=false starts="flowchart TD\n "
  the request carried      tools=none tool_choice=none
  system prompt            bare-Mermaid=true ask-first=false
  usage wall                errors=1
    "The model's usage limit is reached. It resets in 2 hours 15 minutes (at 02:40) — ask again after that."
  RESULT: proven

cd systems/whiteboard/services/ttd-bridge && npm test
  # tests 22   # pass 22   # fail 0
```

The proof runs the real bridge against a stub rail, so it costs nothing and cannot flake on a
cloud model — and it proves the part that matters: **what the bridge sent**, not what a model
happened to reply.

## The unit, and the restart that has not happened

The bridge was a hand-started process, and the unit that was supposed to own it was measured
crash-looping: `activating (auto-restart)`, `EADDRINUSE 127.0.0.1:7313` — a manual process held the
port the unit wanted. Two owners, and neither could tell. That unit also carried
`TTD_MODEL_API_KEY=…` in plain text, which is a credential in a file nobody thinks of as one.

`units/whiteboard-bridge.service` is the replacement: no secret in it (an `EnvironmentFile` at
mode 600 instead), `NoNewPrivileges`, one owner. It was proved by seating it as
`whiteboard-proof.service` on a **spare port, 7391**, leaving the live board on 7313 untouched:
`is-enabled` → `enabled`, `is-active` → `active`, main pid 1527255 → 1542057 across a
`systemctl --user restart`, `/healthz` reporting both modes and seven tools.

Seating it for real means stopping the hand-started bridge that holds 7313 — that is a restart of
the whiteboard, and it waits for the operator's word. The one command is in the README.

## Not done, deliberately

- The **panel** (ticket 0038) and the **thread** with a *Draw it* action are the app's surface and
  need the upstream source forked and built. The panel's cloud line — *what you type leaves this
  machine* — belongs on the panel, not buried in an about box, so it ships with the panel.
- Tools are **declared and relayed**, not executed here: the client runs them against the room the
  person is looking at. A bridge that could act on a canvas nobody is watching would be a door.

## Files

- `systems/whiteboard/services/ttd-bridge/tools.mjs` — new: the seven tools and the boundary
- `systems/whiteboard/services/ttd-bridge/usage-limit.mjs` — new: the wall, in words, with a time
- `systems/whiteboard/services/ttd-bridge/bridge.mjs` — converse prompt, tools in the request, the wall on every failure
- `systems/whiteboard/services/ttd-bridge/index.mjs` — the converse route; `generate` rebuilt on the same handler with no tools
- `systems/whiteboard/units/whiteboard-bridge.service` — new: one owner, no secret in the file

## CHANGE LOG

- 2026-11-13 — review-mend: added missing heading for #729

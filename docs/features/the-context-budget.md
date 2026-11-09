# The context budget — how much room the agent has left

## What it is

Every agent Ymir seats (the counsellor, every Eindri, every seat in Sessrúmnir, and the voice) can be told
how much conversation it is carrying: the tokens of the last turn, the window the model holds, and how many
turns of the same size remain before the engine summarises the older part of the conversation. Before this
existed only the voice could ask, so work ran into the window without warning and died at the ceiling.

The number is not a guess. It comes from the harness itself (`ctx.getContextUsage()`), the model's own
declared window, and the session's own spending — and it is refused, with the reason, when either half is
unknown.

## What you need

Nothing to install: the extension ships in the tree and pi discovers it (`RULES/13`), so a fresh clone and
every update carry it. A seat pinned to a runtime picks it up when that runtime is updated.

## Do it

Ask an agent, or ask yourself through the door:

```
bin/seat/context.sh                 # the session pi wrote most recently
bin/seat/context.sh --json          # the same facts, machine-readable
```

Inside a session, the agent calls its own `context_left` tool, which answers with the same three facts and
also publishes them to `hodd/state/context-left/<session>.json` so the voice repeats one counter instead of
keeping its own.

You should see something like:

```
context_left[9]{tokens,window,percent,compact_at,remaining,user_turns,per_turn,turns_left,state}:
  "120000","200000","60%","183616","63616","8","15000","4","room"
```

## Notes & limits

- **The reserve is read, not assumed**: project settings, then user settings, then pi's documented default
  (16,384 tokens), and the answer names which one answered.
- A **window the model does not declare** is refused by name — a window is never assumed.
- A session with **no measured context yet** (right after a compaction) is refused, with the reason.
- `bin/seat/context.sh` prefers the live reading; for a finished session it falls back to reading the
  transcript and makes no claim to be the live number.

## If it does not work

- `context: no session file found` — the door looked in `~/.pi/agent/sessions/`; pass `--session <file>`.
- `the context window is unknown for <model>` — the model's catalogue entry has no `contextWindow`; name it
  there, or pick a model that declares one.
- Nothing answers and no reading is published — the seat's runtime does not carry the extension yet; run
  `bin/agents/groa-update.sh` (or the install step) on that seat.

## CHANGE LOG

- **2026-11-09** — the page was written with the feature (plan 231 §the six hands; the context budget).

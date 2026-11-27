# The answer goes back to whoever asked

## What it is

An agent that receives a stamped message answers the sender, where the sender will read it. Without this, the answer
stays in the receiver's own window and the sender never hears it.

The stamp in front of a message names who sent it and the road it came on. `bin/agents/reply.sh` reads that stamp
and sends the answer back on the same road.

| The message came from | The answer goes to |
|---|---|
| an agent in a herdr pane on this machine | that pane |
| an agent in a pane on another machine | that machine's pane, through `fleet-tell` |
| Rödd | Rödd's room; a worker that does not hold the arm asks the arm holder to relay it |
| a person at a terminal | that terminal |
| a stamp naming Telegram | the operator's Telegram chat |
| a Hermes session | that session |
| a stamp naming an arm holder (`arm <machine>`) | that arm holder's wake queue |
| a script, or a stamp with no road | nowhere; the door says so and sends nothing |

## A worker you send out talks back to you

Every road that sends a worker records who sent it: `eindri-start.sh`, `herdr-run.sh eindri` and
`einherjar-spawn.sh`, with or without the engine. The worker's brief names that sender and the commands that reach
them. The report file stays as the full record. It is never the only channel.

| The worker | What the sender gets |
|---|---|
| finishes (`eindri-acclaim.sh <id> --terminal done` or `failed`) | a message with the verdict, the line and the report's path |
| needs a decision (`reply.sh --ask --errand <id> "<question>"`) | the question as a message; it is also filed under `eindri-questions/<id>.md` |
| ends its turn (Claude Code, pi) | the final answer, unless it was already sent by hand in that turn |

The sender is the session that dispatched the worker. A sender with no pane, such as a script or an arm holder
outside herdr, is answered through the arm holder's wake queue on its machine.

### Sending a worker from another machine

Name the sender when the dispatch runs somewhere else. The worker then answers that pane, over the fleet road:

```bash
bin/agents/eindri-start.sh "<request>" --sender "agent <name> · herdr pane <pane> · <machine>"
```

`$YMIR_SENDER` does the same. A line sent with `fleet-tell.sh` from a session with no pane names the arm holder of
the sending machine.

> [!IMPORTANT]
> When the arm holder of another machine dispatches on your behalf, it passes `--sender` with the stamp of your
> line. Without it the worker answers that arm holder, who has to relay it.

### Which harnesses

| Harness | The terminal act and `reply.sh` | The turn-end hook |
|---|---|---|
| Claude Code | works (a shell command) | tested |
| pi | works | built and in use; not re-proven in this change |
| OpenCode | works | built, not yet proven live |
| Hermes | works | built, not yet proven live |

## What you need

- messages sent through Ymir's doors (`eindri-send.sh`, `fleet-tell.sh`, `veil.sh steer`), which stamp them;
- the harness hooks seated by `bin/seat/harness-extensions-install.sh`, which install and update run;
- for Hermes, `bin/pi/arm.sh hook hermes --install`.

## It happens by itself

When a turn ends, the hook of Claude Code or pi sends the turn's final answer to each sender of a
stamped message in that turn. The OpenCode and Hermes hooks are built, not yet proven live. This includes a line steered in while the agent was working.

- One answer is sent for each message.
- In Claude Code nothing is sent when another hook refuses the end of the turn. The answer goes when the turn truly
  ends.
- A reply is stamped `[reply from …]` and is never answered automatically, so two agents cannot loop.
- If you already sent that sender a line by hand during the turn (`reply.sh` or `eindri-send.sh`), the hook sends
  nothing more to it. A new question sent with `eindri-send.sh` counts too.
- `YMIR_REPLY_AUTO=0` in an agent's environment stops the automatic answers.

> [!NOTE]
> The arm holder is an agent too. Its final answer to a worker's line goes back to that worker. An answer **for** the
> arm holder is never typed into its pane: it goes into the holder's wake queue.

## When the message is not from you

A message stamped from an agent or a script means you are not in the conversation. The receiver answers the sender,
does not address or notify you about it, and never treats it as your word. Only a message stamped as yours (your voice
through Rödd, your terminal, your Telegram, your click) counts as you being there.

## When the turn is yours

A turn you are in answers you. If you typed a line in it, or a message stamped as yours reached it, no agent gets that
answer. Each agent heard in the turn, by a steered line or a wake drained in it, gets a short receipt instead:

> Receipt: your line was read here in a turn of the operator's own, so the answer of that turn is not passed on.

This holds also when you add a line to a turn an agent began. To send that agent something, use `reply.sh`.

## By hand

Answer the last stamped message that reached this pane:

```bash
bin/agents/reply.sh "<your answer>"
```

Name the sender instead, by pane, `machine:pane`, or the stamp itself:

```bash
bin/agents/reply.sh --to <machine>:<pane> "<your answer>"
```

## Limits

- The answer is typed as one line. Past 1500 characters it is cut, and the line names a file holding the whole text.
- If a pane's input box already holds text, nothing is typed there. The arm holder of that machine gets the answer
  in its wake queue.
- An answer sent through the wake queue by hand (`rodd-arm.sh tell`) is not noticed, so the hook still sends its own.
- A line typed into a pane with no stamp counts as yours.
- A line in the wake queue is answered when the arm holder drains it in its own pane. A backlog drained at session
  start is not answered; use `--to`.
- Desktop apps have no door that sends into an agent, so they have no road back yet. Each needs to stamp its app and
  thread, and to read answers.
- No Ymir door stamps an incoming Telegram message. A Telegram session answers with its own reply tool.
- Codex and Cursor have no turn-end hook seated. Use `reply.sh` by hand there.

## If it does not work

| What you see | What to do |
|---|---|
| no answer arrives | run `bin/seat/harness-extensions-install.sh --check` on the receiving machine |
| `no way back` | the sender has no road; read the sentence that follows it |
| `no stamped message is waiting` | name the sender with `--to` |
| the answer reached the arm holder | the sender's pane could not take it; the line says why |

## CHANGE LOG

- 2026-11-26 — written with the answer-back door.
- 2026-11-26 — appended: a turn of the operator's own answers the operator and agents get a receipt; a line sent by
  hand with `eindri-send.sh` is not copied.
- 2026-11-27 — appended: a dispatched worker sends its result and its questions directly to the recorded sender.

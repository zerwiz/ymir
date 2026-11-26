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
| a script, or a stamp with no road | nowhere; the door says so and sends nothing |

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
- If you already answered with `reply.sh` during the turn, the hook sends nothing more to that sender.
- `YMIR_REPLY_AUTO=0` in an agent's environment stops the automatic answers.

> [!NOTE]
> The arm holder is an agent too. Its final answer to a worker's line goes back to that worker. An answer **for** the
> arm holder is never typed into its pane: it goes into the holder's wake queue.

## When the message is not from you

A message stamped from an agent or a script means you are not in the conversation. The receiver answers the sender,
does not address or notify you about it, and never treats it as your word. Only a message stamped as yours (your voice
through Rödd, your terminal, your Telegram, your click) counts as you being there.

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

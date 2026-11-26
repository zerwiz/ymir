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

When a turn ends, the hook of Claude Code, pi, OpenCode or Hermes sends the turn's final answer to each sender of a
stamped message in that turn. This includes a line steered in while the agent was working.

- One answer is sent for each message.
- A reply is stamped `[reply from …]` and is never answered automatically, so two agents cannot loop.
- If you already answered with `reply.sh` during the turn, the hook sends nothing more to that sender.
- `YMIR_REPLY_AUTO=0` in an agent's environment stops the automatic answers.

> [!NOTE]
> The arm holder is an agent too. When a worker types a report into its pane, the holder's final answer goes back
> to that worker.

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
- Lines that arrive through the wake queue are not answered automatically. The line carries the sender's pane, so
  use `--to`.
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

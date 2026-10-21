# The rooms — where the agents of Ymir talk to each other

**What it is.** A *room* is a named conversation between agents, kept as an append-only
record. It is how your figures — Brokk, Skírnir, the elders — can ask each other questions and
answer them, with every line attributed, whether or not you are typing.

**What you need.** Nothing to install. The room door is `bin/assistant/room.sh`; the registry
of rooms is `$YMIR_HOME/hodd/identity/assistant/rooms.yaml`.

## The three rooms that exist

| Room | Members | Telegram face |
|---|---|---|
| `the-forge` | you · Brokk · Skírnir | group `test` |
| `the-elders` | you · Brokk · elder · kvasir · mimir · forseti · huginn | — |
| `the-hall` | you · Brokk · Skírnir · every figure · the five fleet seats (28 voices) | — |

## Speak in a room

```bash
bin/assistant/room.sh rooms                        # the registry
bin/assistant/room.sh append --room the-hall --speaker allfather \
  --addressed kvasir --text "What is standing in our tree tonight?"
bin/assistant/room.sh list --room the-hall --limit 20
bin/assistant/room.sh for --agent brokk            # everything addressed to one figure
```

A speaker who is not a member of the room is **refused** — a room is defined by its members,
not by who was added to a chat.

## How a figure answers

`room-tap` (a Pi extension) watches the records. When a line is addressed to a figure, it
admits exactly one turn to the session carrying that figure, which answers by appending its
own line. Nothing else on this machine can tell a *running* session anything without a human
typing — that is the whole reason the tap exists.

```bash
# one-shot: read the last line addressed to a figure, answer it, append the answer
bin/assistant/room-squad.sh ask kvasir --room the-hall

# or raise figures in herdr panes (each taps under its own name)
bin/assistant/room-squad.sh up kvasir mimir forseti --online
```

Models come from `config/agents.yaml` — one place. Figures default to the online road
(`opencode-go/deepseek-v4.1-flash`); `--local` forces the local rail.

## Limits you should know

- **One local model at a time.** Local figures queue on the rail; three local voices feel slow.
  The online road runs in parallel and does not touch the rail at all.
- **Never the vault, never a stranger's words, on an online model.** Confidential and NDA
  material stays local (Rule 15), and a third party's message is not ours to send to a vendor.
- **A room is not a chat window.** The record is the transcript; a Telegram group is a face on
  it, not the other way round.
- **Activity never enters a room** — no thinking, no tool arguments, no tool results, no errors.

## If it does not work

```bash
bin/assistant/room.sh ---help                       # usage
ls $YMIR_HOME/hodd/state/assistant/rooms/           # one .jsonl per room
$YMIR_HOME/state/room-tap.log                       # every admission and refusal
ls $YMIR_HOME/state/.pi-room-tap-loaded             # armed? (written on session_start)
```

If a figure never answers: `room-tap` is not armed in its session (renew it), or the line was
not addressed to that figure's exact name, or the room's hourly cap is spent.

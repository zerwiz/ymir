# One Telegram bot per machine, read by the arm holder

## What it is

Each machine has one Telegram bot. The session that holds the arm reads it, whatever harness that session runs in.
When the arm moves, the bot moves with it. The operator's id is written down once and given to every harness.

Telegram allows one reader for each bot. A second reader gets `409 Conflict`.

| The arm holder runs in | What reads the bot | After the arm moves to a session already running |
|---|---|---|
| pi | the pi-telegram package | automatic: the session runs `/telegram-connect` itself |
| Hermes | the Hermes gateway | automatic: the gateway is restarted |
| Claude Code | the Telegram plugin | **not automatic**: see below |
| OpenCode or another harness | nothing: there is no channel | move the arm to a harness that has one |

### pi

The extension `.pi/extensions/gna-telegram-follow.ts` looks every 10 seconds. It acts only in the session that holds
the arm, while that session is idle, and only when nothing reads the bot yet. So it never meets a takeover question.
It tries at most once a minute. The session must have loaded the extension: restart a pi session once after the update.

### Claude Code cannot reconnect by itself

The plugin is a local server that Claude Code starts with the session. With no token it exits at once. Claude Code
offers no command, hook or signal that lets another program restart such a server in a running session. The only
program-free ways are `/mcp`, typed in that session, and a new session. Ymir does not type into the holder's input
box, which is often in use.

The door sends the holder a message in the arm's queue. It asks the agent to search its tools for
`plugin_telegram_telegram`, which in some Claude Code versions retries a server that failed to connect. This has not
been tried. If `status` still shows no reader, run `/mcp` and reconnect the telegram server.

### Hermes

While the desk is in a call the gateway is not restarted. The arm service tries again until the call ends.

A session that **starts** after the hand-over connects by itself in Claude Code.

## What you need

- one bot for the machine, made in `@BotFather`;
- its token in the vault: `bin/vault/hodd-set.sh --stdin TELEGRAM_BOT_TOKEN secrets/telegram-<host>.env`;
- your own numeric Telegram id.

## Turn it on

It is off until your home says so. In `$YMIR_HOME/hodd/identity/machines.yaml`:

```yaml
machines:
  <host>:
    telegram:
      reader: arm
      bot_id: '<the bot id>'
      token_ref: 'secrets/telegram-<host>.env'
```

In `$YMIR_HOME/hodd/identity/operator.yaml`:

```yaml
telegram:
  user_id: '<your Telegram id>'
```

Then run this once:

```bash
bin/notify/telegram-reader.sh sync
```

After that it runs by itself: at `rodd-arm.sh hold` and `release`, and from the arm service about every 15 seconds.

## See where it stands

```bash
bin/notify/telegram-reader.sh status
bin/notify/telegram-reader.sh check
```

`status` shows the holder and, for each harness, whether it has the machine's bot. `check` exits 1 when there are two
readers, or when the reader is not the holder's. No token is printed.

## What it changes on the machine

| File | Holder's harness | Every other harness |
|---|---|---|
| `~/.pi/agent/telegram.json` | token, bot id and your id are written | the machine's token is removed |
| `~/.claude/channels/telegram/.env` | token is written | the machine's token is removed |
| `~/.claude/channels/telegram/access.json` | only your id may write, no pairing | unchanged |
| `~/.hermes/.env` | token and `TELEGRAM_ALLOWED_USERS` | the machine's token is removed |

The first version of each file is kept beside it as `<name>.before-ymir-reader`. A token of a different bot is never
removed from a harness that does not hold the arm. The holder's harness is given the machine's bot in its place.

## Notes and limits

- pi's automatic connect has been tested with a stand-in pi, not with a live bot.
- Releasing the arm leaves the bot unread. An arm holder that dies changes nothing until the next holder appears.
- Outgoing alerts (`bin/notify/send.sh`) post to the Bot API directly with their own token from the vault. They work
  whoever reads, as long as that token's bot is not retired.
- The assistant's own bot is separate. The door refuses to use it as the machine's bot.
- Workers seated by Ymir cannot read the bot: their Claude plugin is pointed at an empty folder.
- A Claude session you open by hand beside the holder can take the plugin's connection. The door stops it, and tells
  the holder to reconnect.
- Hermes cannot be seen by `check`, because its gateway keeps no reader record this door reads.
- On macOS the arm service and these doors use `ps`. The hand-over has not been run on a macOS seat.

## If it does not work

| Message | What to do |
|---|---|
| `telegram.reader is not arm` | add `reader: arm` to this machine's row |
| `no operator Telegram id` | add `telegram.user_id` to `operator.yaml` |
| `no usable TELEGRAM_BOT_TOKEN` | store the token at the row's `token_ref` |
| `the token at … is not the bot the registry names` | correct `bot_id` or the token |
| `the machine's bot is the assistant's own bot` | give the machine a different bot |
| `the desk is in a call` | wait for the call to end, then run `sync` |
| `Telegram update journal belongs to another bot` | run `bin/notify/telegram-seat.sh repair` |

## CHANGE LOG

- 2026-11-27 — first version.

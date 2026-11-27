# One machine, one Telegram bot, read by the arm holder

**Date:** 2026-11-27 · **Component:** notify (`bin/notify/telegram-reader.sh`)

## What was wrong

One machine had two bots. pi read one from its own config, and the Claude Code Telegram plugin read another from
its own, each with its own allowlist. The operator had to know which harness was working to know which bot to write
to. Telegram allows one reader for each bot, so the two harnesses could not simply share one.

## What changed

- `bin/notify/telegram-reader.sh` moves the machine's bot to the harness of the arm holder. It withholds the token
  from every other harness and stops their pollers first. When one cannot be stopped, nobody is given the bot.
- The bot is named by the machine's row in the home's registry, and the allowlist by `operator.yaml`. The door is off
  until the row says `reader: arm`.
- `bin/voice/rodd-arm.sh` runs it on `hold` and `release`. The arm service (`src/ymir_runtime/watch.py`) runs it
  when the holder changes and on a slow beat, which stops a stray second reader.
- `bin/seat/herdr-run.sh` points a worker's Claude plugin at an empty folder. The plugin stops any earlier poller of
  the same folder, so a worker's start could have taken the holder's connection.
- A seat or test with its own lock folder never moves the machine's bot.

## What is not closed

- pi and Claude Code cannot be made to start reading inside a running session. The door names the one command.
- pi is stopped by recording another owner in its `state.json`, which pi-telegram watches every second. This reads a
  format that is not Ymir's, and a new pi-telegram release could change it.
- The test uses stand-in processes. Neither the real pi-telegram nor the real plugin was run against a live bot, and
  no macOS seat was used.

## Where the proof lives

`bin/notify/tests/test_telegram_reader.sh`, gate `telegram-reader`: the bot follows the arm across pi, Claude Code
and Hermes, one harness holds it at a time, a stray poller is stopped, a different bot is left alone, and nothing is
written while the arm is vacant or the home has not opted in.

## CHANGE LOG

- 2026-11-27 — first version.

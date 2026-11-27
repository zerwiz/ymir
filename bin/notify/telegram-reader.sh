#!/usr/bin/env bash
# telegram-reader.sh — one bot per machine, read by the harness of whoever holds the arm.
#
#   telegram-reader.sh status            # who holds the arm, and which harness has the bot
#   telegram-reader.sh check             # exit 1 on two readers, or a reader that is not the holder's
#   telegram-reader.sh sync              # move the bot to the holder's harness (idempotent)
#   telegram-reader.sh sync --released   # the arm was given back: nobody reads
#
# OFF until the home says so. In $YMIR_HOME/hodd/identity/machines.yaml, on this machine's row:
#   telegram: { reader: arm, bot_id: '<id>', token_ref: 'secrets/<file>.env' }
# and in hodd/identity/operator.yaml, the one allowlist:
#   telegram: { user_id: '<the operator's Telegram id>' }
#
# Channels: pi (pi-telegram), Claude Code (the telegram plugin), Hermes (its gateway). A holder
# with no channel leaves the bot unread and says so. A token is never printed.
# `sync` is run by bin/voice/rodd-arm.sh (hold, release) and by the arm service.
#
# Exit: 0 done or off · 1 refused or a reader stands where it must not · 2 usage.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1-}" in -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

# A PRIVATE SEAT'S ARM NEVER MOVES THE MACHINE'S BOT: a worker or a test runs with its own lock dir.
primary="${XDG_STATE_HOME:-$HOME/.local/state}/ymir"
if [ "${1-}" = sync ] && [ -n "${BROKK_MACHINE_STATE_DIR:-}" ] && [ "$BROKK_MACHINE_STATE_DIR" != "$primary" ] \
   && [ "${YMIR_TELEGRAM_READER_FORCE:-0}" != 1 ]; then
  printf 'telegram-reader[1]{result,detail}:\n  "private-seat","this seat has its own lock: the machine bot is not moved"\n'
  exit 0
fi
exec python3 "$HERE/telegram-reader.py" "$@"

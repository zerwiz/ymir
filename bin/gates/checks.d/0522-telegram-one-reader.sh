#!/usr/bin/env bash
# telegram-one-reader — one bot per machine, never two readers, and the reader follows the arm.
gate telegram-reader "the machine's Telegram bot has one reader, and it follows the arm" \
     bash "$ROOT/bin/notify/tests/test_telegram_reader.sh"

#!/usr/bin/env bash
# notify-buttons-on-the-line — a phone line that leaves a decision arrives with its controls.
#
# PLAN 305. The house writes buttons in one grammar (bin/notify/telegram-buttons.sh) for the bridge
# to parse, but a cron line has no session behind it: bin/notify/send.sh posts straight to the Bot
# API, so the message needs the API's own reply_markup. This gate proves the markup reaches the
# wire, that the caller's rows are kept, and that a button which could not render is REFUSED rather
# than sent as prose.
gate notify-buttons "a phone line carries its buttons, and a button that cannot render is refused (plan 305)" \
     python3 "$ROOT/bin/notify/tests/test_send_buttons.py"

#!/usr/bin/env bash
# hall-keeps-changes — the first agent keeps the user's soul lines and config additions across setup.
gate hall-keeps-changes "the first agent keeps the user's soul lines and config additions across setup" \
     bash "$ROOT/apps/bilskirnir/tests/keeps-user-changes.sh"

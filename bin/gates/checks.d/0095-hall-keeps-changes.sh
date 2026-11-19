#!/usr/bin/env bash
# hall-keeps-changes — the first agent keeps the user's soul lines and config additions across setup.
# While the hall is in this tree its own test runs here; once it has left for its own repo (the split,
# 2026-11-19) the same test runs in that repo's CI, and Ymir judges the installed hall through apps.sh check.
if [ -f "$ROOT/apps/bilskirnir/tests/keeps-user-changes.sh" ]; then
gate hall-keeps-changes "the first agent keeps the user's soul lines and config additions across setup" \
     bash "$ROOT/apps/bilskirnir/tests/keeps-user-changes.sh"
fi

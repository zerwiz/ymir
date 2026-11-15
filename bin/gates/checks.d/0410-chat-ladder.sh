#!/usr/bin/env bash
# PLAN 275 item 23 — the rail could not load its model while the voice engine held the card,
# and the chat could only say "no model backend answered". A chat now falls to a model that
# fits and says which answered; a full card is called by its name; the voice idles out.
gate chat-ladder "a chat that cannot load the big model answers from one that fits, and says which did" \
     node --test "$ROOT/apps/hlidskjalf/server/chat-ladder.test.ts"

## agents · 2026-10-23 — only his private chat answers on all; a group answers only when named

**His words:** *"does he answer even if he's not talked to in chats in telegram now?"* → *"only my private
chat should be answering on all. groups never. this are a rule."*

Both true. Two rooms had been set `addressed_only: false` that morning (for a client's sake) and from then
on he answered every message in them — measured: `19:33:58`, an unaddressed *"hi"* in a room, answered.
The same evening he answered the wrong subject to the Allfather (*"What do you know about email?"* →
*"Andre prefers project updates by email"*). An unprompted answer plus a wrong fact is a wrong fact said
in front of a client.

```
law[3]{place,answer,note}:
  "his private chat","EVERY message","the one room that is his alone"
  "a group","only a message that NAMES him (skirn/skirm/skrin/skírni/skirnir/brokk/ymir/@bot) or one from himself","a group is other people; `owner_trusted` grants him, never the room"
  "a group not on the allowlist","nothing at all","`allow <id>` opens the room — still name-only"
```

**The switch was deleted, not switched off** — a law that lives in a YAML key is one edit away from being
unmade, and this key had already been flipped once by a good intention:

- `bin/assistant/telegram.py` — `addressed_only` removed from `load_groups()` and from the addressee rule.
- `bin/assistant/group-add.sh` — `allow` grants the room and never the loudness; `close` removes the room,
  so closed means silent rather than name-only.
- `hodd/identity/assistant/groups.yaml` — both `addressed_only: false` lines and `why_open` removed; the
  header carries the law and its date.
- `bin/assistant/smoke.sh` — section B inverted: it used to *require* an open room; it now requires that
  **no room answers an unnamed message**, and it runs `adapter-test.sh` so the rule is proven in code.

**Measured:** `adapter-test.sh` 6/6 (typing · owner DM · an unnamed group message ignored · an addressed
one answered · a banned chat silent · a bot starts no loop) · `group-add.sh` prints `when named` for all
three rooms · `smoke.sh` **38 pass · 0 skip · 1 fail** (the far-side ear naming a unit that does not exist
on this box).

**A regression the suite caught, worth recording:** the first keep-alive loop waited four seconds before
its first `sendChatAction`, and `adapter-test.sh` failed with *"typing — no sendChatAction"*. It now fires
immediately, then every four seconds. That is exactly why the adapter suite is now part of `smoke.sh`.

**Still owed, and named:** the one-word matcher that chose Andre. A law about the room stops the wrong
fact reaching a room; it does not stop the wrong fact. Plan 112, next.

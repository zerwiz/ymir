## snotra · 2026-10-23 — the room that ignored him, and the skip that said nothing

**The Allfather's report:** *"why don't skírnir answering in this telegram chat?"* — with Reygan's two messages
("Hey", "Who are you?") and no reply.

**The messages arrived.** The journal shows all three updates (`181256873/74/75`) on chat `-5435500944`. He
ignored them **by design**: a group is *addressed-only* — he answers only when his name (or Brokk/Ymir) is in
the text, or when the sender is the owner. Reygan wrote neither.

```
fault[2]{fact,evidence}:
  "the rule","`addressed_only` was implied and global: every group was name-only, with no way to say otherwise","`telegram.py` read `named or trusted_owner` and `continue`d — silently"
  "the silence","the skip printed nothing","a room could not tell 'he is ignoring us' from 'he is broken'"
```

**Fixed two ways:**
1. **a per-room flag** — `groups.yaml` now carries `addressed_only` (default `true`); the Allfather's room with
   Reygan is set **`false`**, so he answers any message there. A room is a policy, not a global.
2. **the skip speaks** — an unaddressed group message now logs *"skipped an unaddressed group message
   (collaborator)"*, so the next person debugging this sees the reason instead of silence.

**Verified:** `--channel telegram-group --chat -5435500944` → *"Hey"* → *"I'm his assistant. I answer what I
can and pass the rest to him"*; *"Who are you?"* → *"Skírnir, his assistant. I take questions and messages;
the decisions are his."*

**And he apologised to Reygan himself** — one line in the room explaining that the room was name-only and
that it is fixed, because the person who was ignored is owed the reason.

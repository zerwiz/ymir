## agents · 2026-10-22 — he knows the house itself now, not three sentences about it

**His words:** *"he needs to know a lot about ymir… we have the FEATURES.md and the lore.md"*. He was right:
the digest was 21 facts and most questions about the house earned the honest no.

```
built[3]{piece,what_it_does,measured}:
  "`bin/assistant/learn-house.sh`","derives one approved fact per named thing in `docs/lore.md` and per row of `FEATURES.md` — the house's own PUBLIC documents, so nothing private crosses","**97 derived facts**, 21 → **120** in the digest"
  "**verbatim**","every derived fact carries `verbatim: true`, so the model reads it and cannot reword it — a paraphrased feature description is how a catalogue becomes a rumour","'does Ymir have a ward' now answers with the real paths instead of a guess"
  "the generator owns only its own work","a fact it marked (`generated_by: bin/assistant/learn-house.sh`) and no longer produces is removed; anything the Allfather approved by hand is untouched","11 stale facts removed on the second run, none of his"
```

**And the name law travels with the derivation:** the lore says "Odin's high seat"; the derived fact says
"the Allfather's high seat". The rule binds the mouth, not just the prompt.

**Also fixed in the same pass — a fact may forbid paraphrasing.** `verbatim: true` rides from the
front matter through `kb-export` into the digest, and the mouth skips the model for those facts. The
three company facts carry it: the model had turned *"active, and his alone"* into *"the **sole** active
company"* — false, because WayOf is active too. With the facts corrected to say *"one of the three"* and
marked verbatim, he now repeats what he was told.

**Verified:** `walls-test` holds (35 assertions, including the mouth→ear round trip) · the four questions
above answer from the derived facts at the stranger tier as well.

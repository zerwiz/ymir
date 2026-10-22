## agents · unversioned · 2026-10-22 — when he does not know the name, he asks for it

### What

`bin/assistant/skirnir.py` gains `asks_about_a_person()` and a two-argument `say_unknown()`: a question
about somebody he does not hold now answers

> *"I don't know Marta Lindqvist yet. Who are they, and what should I know? I'll put it up for the
> Allfather's approval before I hold it."*

instead of the generic *"I don't have that"* dead end. A question about the house itself (`what is Ymir`,
`who is the Allfather`) is recognised as **not** a person question and takes the ordinary path.

### Why

The Allfather, 2026-10-22: *"if he's not knowing the name from his asking he could ask for their name."* A
refusal ends a conversation; asking for the name begins one, and the answer can then be approved into the
digest through the door that already exists (`learn.sh` → approval).

### Verified

- `asks_about_a_person("who is Marta Lindqvist?")` → `Marta Lindqvist`; `"have you met Tarik?"` → `Tarik`;
  `"what is Ymir?"` and `"who is the Allfather?"` → `None` (not person questions).
- `say_unknown("stranger", "Marta Lindqvist")` returns the asking line; the owner path is unchanged.
- `python3 -c "ast.parse(...)"` clean.

### Not verified / not done

- `bin/assistant/walls-test.sh` reports **2 failures at HEAD**, before this change (the tie-refusal and the
  model-context cases) — pre-existing, unrelated, and not investigated here.
- The voice loop (`snotra-voice.py`) composes through `ask.sh`, so it inherits this behaviour on its next
  turn; no live meeting was used to prove it.

# 2026-11-01 — the roll knows a surface that is not ours

**Component:** collab (Vingólf) · **Door:** `bin/collab/who.py` · **Plan:** 154

## Why

The Allfather corrected the record: two of the people we work with are collaborators who use **Trello**, not the
team suite, and a third is in **both** Trello and the suite.

Two consequences, both in this change:

1. **The register names Trello as an account field**, so a person whose surface is not ours is still declared
   rather than dropped. A person who is in both carries `trello:` beside their suite identities; a person who is
   Trello-only carries Trello alone, because their suite login was disabled on his word (it was never used).
2. **`who` no longer calls such a person "unentered".** A person with no measurable account but a declared surface
   this door cannot read now reads **`elsewhere (trello)`** — because "unentered" is a claim about them, and it
   would be false. A false absence is the same fault as a false green.

## What changed

- `verdict` gains a fourth value: `entered` · `unentered` · `drift` · **`elsewhere (<surface>)`**.
- The test grew a third fixture person with only a `trello` account, and asserts the verdict — 22 proofs, all
  passing.

## Measured

Two people read `elsewhere (trello)` and their suite cells are `—`, because the register declares no suite account
for them: the machine still holds the disabled entries, and the record says they are closed. When the register and
the machine disagree again, `who` will say `drift` — that is what the word is for.

**No person's name or address is written here, in the register's place in the repository, or in the door.** The
register that holds them lives in the private home; this file describes the mechanism only.

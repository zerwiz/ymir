# The lore named an NDA product

**Date:** 2026-11-10 · **Component:** gate · **Door:** `docs/lore.md`

## What was wrong

The lore table's memory row named a product and its MCP door as the engine of the memory shelf — in this
repository, which is **public**. The Allfather named the project as NDA on this day: *"we also have the
project anchor. thats also nda."*

Nothing operational changed with the rename; a reader still learns what the machine does.

## What was forged

The row now says the shelf's engine as a capability — *the house memory plane and its MCP door* — which is
true and carries no project's name.

The same name was removed from the Engineering CoE (ten places, including a skill that told a hand to
write to it) and the operator's NDA denylist now carries its **phrases**, not its word, because the short
name is an ordinary English word.

## Verified

`grep -c "anchor-memory" docs/lore.md` → 0.

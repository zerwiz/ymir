# The operator is named in every answer — and the rule now states it twice

**Date:** 2026-11-10 · **Component:** agents · **Doors:** `bin/agents/seat-identity.sh`,
`bin/seat/seat-surface.sh`, `AGENTS.md`

## What was wrong

The Allfather: *"why are not this machine saying the operator's name as the other seat are doing? we should have
appended logic for ymir to also always call the allfathers by name."*

The rule was **already there** — line 13 of this seat's rendered contract said *"The operator of this fleet
is <the operator>. Address him as <the operator>"* — and the hand answering him said "Allfather" alone all
session. So the fault was the hand's, not the machine's, and that is worth saying plainly rather than fixing
the wrong thing.

But a rule a model reads once, in a paragraph, and then forgets is decoration. Two changes make it harder to
forget and impossible to lose:

1. **The render states it as a law, in the sentence a check can look for**:
   *"Name him in every answer — 'Allfather' alone names nobody in a federated hall, so never leave the name
   off."*
2. **The shared contract carries it a second time**, in the voice section where conduct is taught, with the
   reason and the date — so a seat that reads the contract for how to speak also reads who it is speaking to.

## What was forged

- `bin/agents/seat-identity.sh` — the seat header's operator paragraph is now the law, with the quote and the
  note that the rule existed and the hand was careless.
- `bin/seat/seat-surface.sh` — the same sentence in `.hermes.md`, and `--check` **refuses a render that loses
  it**: the older, weaker form (a name somewhere in the file) now fails as *"names the operator but not the
  law that he is named every time"*.
- `AGENTS.md` — *Name him* in the voice section, with the operator's own words and the date.

## Verified

```
$ bin/seat/seat-surface.sh --check
seat-surface: seat file names Hávi ✓
seat-surface: seat file names the operator (<the operator>) and the sentence that forbids leaving it off ✓
seat-surface: SOUL.md carries the house identity ✓
$ sed -n 13p ~/.pi/agent/AGENTS.seat.md
**The operator of this fleet is <the operator>. Name him in every answer** — "Allfather"
```

## CHANGE LOG

- **2026-11-10** — the law stated twice, and the check that refuses to lose it.

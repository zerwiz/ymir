# Fix — the deeper well has its name in the map, and its first trial is recorded

**What was wrong.** Plan 260 sealed the name **Sökkvabekkr** for the deeper well, the memory layer that Honcho
provides. It also said the naming map gains the row in the same change that builds H0, its first trial. The map had no
such row. Its `platform` table also claimed 55 rows while it held 56, so a reader of the TOON count was already one
short.

**What was done.**

- `.agents/assets/agents/naming.md` gains the row *"The deeper well (derived memory)" → Sökkvabekkr*. The table's
  count now reads 57, which is the true number of rows.
- `docs/lore.md` gains Honcho in the *Borrowed Anvil* table, named Sökkvabekkr, with its licence (AGPL-3.0 server)
  and its status (on trial).
- No code ships. H0 was a throwaway trial on one machine, and its stack was removed afterwards. Its numbers and
  verdict live in the private home, in plan 260 and in the research note it names, because they are the operator's
  records (RULES/04).

**How it is proven.** Count the rows: `awk 'NR>7 && /^```/{exit} NR>7 && /^  "/{n++} END{print n}'
.agents/assets/agents/naming.md` prints 57, the number in the header.

## CHANGE LOG

- **2026-11-12** — written with the trial of plan 260, phase H0.

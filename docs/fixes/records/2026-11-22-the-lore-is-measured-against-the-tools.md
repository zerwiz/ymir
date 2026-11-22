# The lore is measured against the tools

**Date:** 2026-11-22 · **Component:** records (`bin/records/lore-audit.sh`, `docs/lore-claims.tsv`) · **Plan:** 350 part A

## What was wrong

The saga and the homepage promise systems: sealed sandboxes, a guard that signs every agent's introduction, a
skill forge, a loop-breaker on watch. Nobody had measured those promises against the running tools. The
operator's question was plain: *"do we have a functioning function for every feature the saga tells?"* Nothing
could answer it.

## What was built

- `docs/lore-claims.tsv` has one row for every system the saga names, plus the Veil, Eir and Gróa: 44 rows. Each
  row gives the claim, the door that should keep it, one read-only command, and what the output must show.
- `bin/records/lore-audit.sh run` measures every row. A door that bears the claim out is **true**. A door that does
  not is **partial**. No door is **false**. A system the house records as not yet built is **planned**.
- `lore-audit.sh watch --notify` keeps the last measurement. It names any claim that was true and is not now, and
  hands it to the arm holder through the Veil. The cron template runs it every Monday at 09:30 on the heart.
- The first measurement is in the operator's home, with the word changes the homepage needs. On the dev machine
  it found 23 true, 14 partial, 3 planned and 4 false.

## Proof

- `bash bin/records/tests/test_lore_audit.sh` — 11 passed.
- The gate row `lore-audit` (`bin/gates/checks.d/0548-lore-audit.sh`) runs it.

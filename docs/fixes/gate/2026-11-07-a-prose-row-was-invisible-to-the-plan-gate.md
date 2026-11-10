# A prose index row was invisible to the plan gate

**Date:** 2026-11-07 · **Component:** gate · **Status:** fixed; the gate now reads both row shapes

## The fault

`bin/gates/plan-audit.sh` checks that every plan has "an index row that names the plan AND carries a status".
It read a row's cells by splitting on `|` only — the **table** shape:

```
| 11 | [A plan](11-bare.md) | opened |
```

This ledger's recent rows are **prose** rows, separated by a middle dot:

```
- **Plan 217** — [The plans reach the board](217-plans-reach-the-board.md) · opened 2026-11-07 · **proposed** — …
```

Split on `|`, that line is *one* cell that begins `- **Plan 217**` — so no status token was ever found in it, and
the gate reported **"row at README:NNN carries no status"** for every prose row that carried one perfectly well.
The fault was found while writing plan 217: its row said `**proposed**` in the house's own shape and the gate still
called it stateless. Four plans were checked by hand before the pattern was named — 208, 211, 216 and 217 all
failed the same way.

## Why it was possible

The gate's own self-test built a **table** fixture:

```
| 11 | A plan | `11-bare.md` |
```

So the test proved the shape the test used. A gate that only ever sees its own fixture can be perfectly green while
the shelf it governs is misread — the same class of fault as a count that reads a spelling instead of a structure
(the audit's own header, 2026-10-24).

## The fix

1. A row is split into cells on `|` **and** `·`, so both shapes are read.
2. The **number cell stays the first pipe cell, untouched** — `20 · twin a` is a suffixed row, and its suffix is
   what frees a shared number (Rule 06). Splitting the number cell would have broken the twin rule, and the
   self-test caught exactly that when the first version of this patch did it.
3. A status may also be **bold anywhere** on the line (`**open**`), read in `STATUS_WORDS` order.
4. The self-test now rewrites its stateless row into the **prose** shape and asserts the status is read — so the
   gate tests the shape the shelf actually uses.

## Measured

```
before[1]{plans,gaps,row-gaps}:  163,306,38
after[1]{plans,gaps,row-gaps}:   163,286,18
self-test: PASS (11 cases, one of them new)
```

Twenty rows that were honest stopped being reported as faults. The eighteen that remain genuinely carry no row or
no status, and are now a true reading rather than a mix of true and false.

## Files

- `bin/gates/plan-audit.sh` — the cell split, the bold-token scan, and the new self-test case.

## CHANGE LOG

- **2026-11-09** — the note was carried into the integration branch whole, its history with it.

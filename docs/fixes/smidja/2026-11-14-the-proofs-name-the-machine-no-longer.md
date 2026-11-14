## smidja · 2026-11-14 — the proofs name the machine no longer

### Why

The helm's audit of the rename's branch found **four added lines that named this seat or a user's
home path**. Under the agnostic law (RULES/25, RULES/04) a proof says *this machine*, never which
one, and a store is named through the resolver (`$YMIR_HOME`), never as an absolute home — a document
that spells a hostname puts one machine's facts in a public tree, and the next seat reads them as its
own.

The four:

| Where | It said | It says |
|---|---|---|
| `apps/smidja-factory/apps/visualizer/server/volundr.test.ts` | `Measured on <the seat> 2026-11-14: …` | `Measured on this machine, 2026-11-14: …` |
| `docs/fixes/smidja/2026-11-14-kaia-answers-and-failure-says-what-failed.md` (proof quote) | `… seated here on <the seat> …` | `… seated here on this machine …` |
| the same note, the store's path | `<one user's home>/Documents/ymirhome/smidja/smidja.db` | `$YMIR_HOME/smidja/smidja.db` |
| `docs/fixes/smidja/2026-11-14-kaia-is-volundr-the-master-of-the-smiths.md` | `read through the DevTools protocol on <the seat>` | `read through the DevTools protocol` |

The "it said" column is masked as well, on purpose: a record of a masked name that reprints the name
unmasks it again, and the next audit would be right to flag its own fix note.

Two of the four came in from `eindri/smidja-header-chat`. The helm directed that they be fixed here,
on the rename's branch, rather than waiting for that branch to be mended — so they are fixed here.

### What changed, and what deliberately did not

- The **findings are unchanged**: the same 25 tests, the same measured behaviour, the same summaries.
  Only what identifies the seat the measurement was taken on is gone.
- The other note's **CHANGE LOG carries a dated line** recording the mask, so the record says what was
  done to it and why (RULES/06 — a correction is written down, never silent).
- Quotations of the *old, wrong* code keep their `$HOME/Documents/ymirhome` spelling where a fix note
  shows the fault being repaired: a record of a defect must quote the defect.

### Proof

- `git diff origin/main...HEAD` added lines: no hostname and no absolute home path remains, apart from
  a synthetic `/home/x/…` in a test fixture (that is how a path assertion is written at all) and the
  scanner's own detector class `/home/zerwiz[A-Za-z]*/`, which names no user.
- `vue-tsc --noEmit` clean; `bun test` → 25 pass, 0 fail.
- The branch pushed past `fixes-guard`, `guards.sh`, `branch-current` and `no-delete-guard`.

### Owed

Nothing. The wider tree still carries hostnames in older fix notes; masking them is a sweep of its
own, not this errand's.

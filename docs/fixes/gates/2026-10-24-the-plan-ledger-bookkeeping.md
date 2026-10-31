# The plan ledger's bookkeeping, and a check that reads the outline

**Date:** 2026-10-24 · **Component:** gates · **Branch:** `eindri/ledger-bookkeeping` (local-only, no PR)

## What was wrong

The ledger was audited by hand this morning (`hodd/docs/audits/2026-10-24-the-plan-ledger-audited.md`)
and the hand lied about one of its own measures — the audit said so itself:

```
faults[4]{fault,symptom}:
  "no check existed","the seven-item plan contract lived as prose in an audit, so nothing stopped the next 62 plans from slipping"
  "the audit's worst number was its own","'plans carrying explicit Phase N headings: 10 of 62 (16%) — UNFAIR AS MEASURED'. It counted a WORD where the plans carry numbered sections"
  "four numbers used twice","72 · 86 · 93 · 94 — a citation like 'plan 93' no longer names one thing"
  "two thirds of the shelf was unfindable","'44 of 62 root plans have no index row'"
```

Re-measured on the shelf today (67 numbered plans — plan 129 landed after the count), the "44" splits into
two different faults that need two different patches:

```
plan_citation[4]{measure,count,what_it_means}:
  "cited by a markdown LINK","24","the audit's 44 counted this: 42 lack a link today"
  "cited by a bare `path` (old 3-column row)","19","a row EXISTS; it has no status cell"
  "cited by nothing at all","23","the true missing-row set"
  "plans whose README row carries a status","26","39% — the rest state no state"
```

That distinction is load-bearing: **Rule 06 forbids rewriting an existing row**, so the 23 are an append and
the 19 are not. Conflating them would have had a hand editing 19 rows that the law says to append to.

## What this does

1. **`bin/gates/plan-audit.sh` — the contract as a check.** Per plan it reports: his words (quoted, dated),
   a measured section, phases with a proof, what it refuses, the questions that are his, a unique number,
   and an index row with a status. `--check` exits nonzero on a gap; `--json` for machines; `--rows` emits
   the missing README rows; `--shelf DIR` audits another shelf; `--self-test` proves it bites.
2. **It reads the OUTLINE, not the spelling — the audit's caveat made into code.** A phase is what the plan
   declares: a `Phase N` heading, a `phases[]` TOON block, the items of a `## Phases` section, or numbered
   sections `## N ·`. A proof may live inside the phases or in a dedicated acceptance section, because that
   is how plan 69 and plan 73 actually state "each ending in something observable". Applying it to the shelf
   moves the audit's worst number from **16% to 60%** — the 16% was a vocabulary count, not a structure.
3. **Two checks refuse to be narrow where the house is broad.** An `asks[3]{question,why}:` TOON block is
   how the house states questions, and `laws[]` / a stated prohibition is how it states a refusal; a test
   that read only prose headings reported gaps where the plans had answered. Both were found by running the
   gate against the real shelf, not by reasoning about it.
4. **A SKIP is not a FAIL.** The ledger lives in the operator's private home and CI has none, so an absent
   shelf prints `SKIP` and exits 0 — the lesson `bin/gates/queue.sh` already carries.
5. **Wired into `bin/gates/ci-verify.sh`** so it cannot exist and run nowhere.
6. **A ratchet, not a wall — and it refuses to set its own baseline.** The shelf carries 142 historical
   gaps, so a gate that failed on all of them would be red on arrival and would be commented out within a
   week. `--baseline` records the shelf as it stands, once; from then on `--check` fails only on a gap that
   is **new**. The baseline lives in the machine's state dir (`$YMIR_STATE_DIR/plan-audit-baseline.json`),
   because every seat holds its own copy of the ledger and a repo baseline would be another machine's gaps.
   **Recording is an explicit act, never automatic**, and that is deliberate: `usage-ratchet.sh` records a
   missing baseline on its own, but this gate must not write to the ledger's home — and, more to the point,
   it must not decide for the Allfather that 142 gaps are acceptable. So the first act after merge is one
   command, and until it is run `--check` says so:

```bash
bin/gates/plan-audit.sh --baseline    # accept the ledger as it stands, once
```

## The bugs the real shelf found in this gate (recorded, not tidied away)

Each was invisible on a synthetic fixture and obvious on the ledger:

```
found_by_running_it[4]{bug,what_it_would_have_reported}:
  "a section read as the title","plans 94 and 97 use a single `#` for their sections; reading the LAST `# ` line as the H1 made plan 94 look like 'plan 4'"
  "`### Status of P1` matched the step token","one incidental heading swallowed a plan's whole numbered outline, and 68 was reported phase-less"
  "a number-cell match hid the real fault","with 86 used twice, the switch-games row was returned as heart's row, so 'heart has no row' read as 'its row has no status'"
  "metadata paragraphs wrap","dropping `**Builds on:**` by line left its tail, and proposed rows began mid-sentence"
```

The second one is the whole argument for the gate in miniature: a loose token read a heading that merely
*mentioned* `P1` and concluded a plan had one phase. That is the audit's 16% wearing a different hat.

## Verified

```
bin/gates/plan-audit.sh --self-test      PASS  (10 assertions, both directions)
bin/gates/plan-audit.sh --check          exit 1 — 142 gaps over 67 plans, and says to run --baseline
bin/gates/plan-audit.sh --baseline       records 142 known gaps; --check then exits 0
bin/gates/plan-audit.sh --shelf /nowhere exit 0, "SKIP"   (CI has no vault)
bin/gates/plan-audit.sh --rows           23 rows, oldest number first
```

The self-test asserts the thing the audit got wrong: a plan whose phases are numbered sections and which
carries no `Phase N` heading anywhere must **pass**, while a prose-only plan must **fail**.

## What is deliberately NOT done here

The 23 rows, the five number-cell amendments and the 19 status backfills are a **proposal** in
`state/ledger-bookkeeping.md`, not a commit — they are writes to the Allfather's vault, and this errand
touches nothing outside its worktree. Brokk applies them by `ymir_push` after the Allfather's word.

Two findings stand outside the index and are recorded rather than fixed: plan `78` is an empty shell (its
whole opening is `**Opened 2026-10-14.**` and a rule), and plan `125` still carries `# Plan 122` in its H1
after the renumber. Both are the ledger's to correct, not a gate's to rewrite.

# The plan ledger and Runes

## What it is

Two records of what Ymir has decided and done:

- **The plan ledger** — the plans live as files, one shelf per project, in the hoard:
  `$YMIR_HOME/svartalfaheim/<realm>/projects/<project>/plans/`. A `register.md` on that
  shelf lists every ask and open question, append‑only. Anything plan‑sized is
  **written first**, then built.
- **Runes** — the append‑only audit ledger: every significant action is *carved*, and
  each entry **chains to the one before it** by folding the previous checksum into its
  own. The chain means a record cannot be quietly edited or dropped.

Plans are *intent*; Runes are *fact*.

## What you need

- Ymir installed. The records live in the hoard (`$YMIR_HOME`), never the tree
  (Rule 04).

## Do it

**Read the plans.** They are Markdown files on the project's shelf; the index is that
shelf's `register.md`:

```bash
bin/vault/hodd.sh path                          # the hoard root
ls "$(bin/vault/hodd.sh path)"/../svartalfaheim/*/projects/*/plans/ 2>/dev/null
```

**Append to Runes** — a significant action is recorded by the runtime; you rarely call
it by hand, but you can:

```bash
bin/records/runes-append.sh --help
```

**Regenerate the ledger view.** `runes_audit.md` is a *projection* of the event set —
deterministic, byte‑identical on every seat:

```bash
bin/records/runes-project.sh
```

**A seat's own state** (pids, locks, leases) resolves through one door:

```bash
bin/records/ymir-state.sh
```

## Notes and limits

- **Append‑only (Rule 06).** A correction is a **new** entry citing the old one; the
  ledger, the rules, the fix notes and everything in `$YMIR_HOME` are never rewritten.
  A move must carry every append‑only artifact with it.
- **One writer for the chain.** The chain law lives in one implementation
  (`src/ymir_runtime/state/runes.py`); the shell door is a thin shim, so there is no
  second implementation to drift.
- **Plans are private.** They live in the hoard, never under `docs/` in the tree.
- **Runes are fact, not judgement.** The ledger records what happened; the *plan*
  records what was meant. When they disagree, read both.

## If it does not work

| What you see | What to do |
|---|---|
| No plans shelf | The project is not registered under a realm's `projects/` — create its shelf and a `register.md`. |
| `runes-project` gives a different file than a peer | An equivocating seat emitted two events on one parent; the projector quarantines the siblings deterministically (nothing is deleted). |
| A rune write is refused | The chain head moved under you — re‑read the head and retry; the lock makes a torn chain impossible. |
| A plan is missing after a move | A move dropped an append‑only artifact (Rule 06) — recover it from the backup; verify the set by name. |

## Auditing the ledger — the plan contract as a check (2026-10-24)

A plan in this house carries seven things: **his words** (quoted, with a date), **a measured section**,
**phases that each end in something observable**, **what it refuses**, **the questions that are genuinely
his**, **a number used once**, and **an index row carrying a status**. That contract used to live only as
prose in an audit, so nothing stopped the next sixty plans from slipping. Now it is a gate.

```bash
bin/gates/plan-audit.sh            # every plan on the shelf, seven verdicts each
bin/gates/plan-audit.sh --check    # exit 1 on any gap (wired into bin/gates/ci-verify.sh)
bin/gates/plan-audit.sh --rows     # the README rows to append for plans that have none
bin/gates/plan-audit.sh --json     # the same verdicts, machine-readable
bin/gates/plan-audit.sh --self-test
```

**What it reads.** The outline, not the spelling. A phase is whatever the plan *declares* — a `Phase N`
heading, a `phases[]` TOON block, the items of a `## Phases` section (a table is fine), or numbered
sections `## N ·`. A proof may sit inside the phases or in a dedicated acceptance section, because that is
how `69` and `73` state "each ending in something observable".

**Why that matters.** The audit that commissioned this gate measured "plans with explicit `Phase N`
headings" at 16% and flagged its own number as unfair — it had counted a word. Reading the outline instead,
the same shelf scores 60%. A measure that reads vocabulary will always under-report a house that writes in
prose, and it is the same mistake as trusting a green service unit instead of the socket.

**A ratchet, not a wall.** The shelf carries historical gaps, so failing on all of them would make the
gate red on arrival. `--baseline` records the shelf as it stands, **once**; from then on `--check` fails
only on a gap that is new. Recording is an explicit act — the gate will not write to the ledger's home and
will not decide for you that the ledger is acceptable as it is. Until a baseline exists, `--check` says so
and names that one command.

**Limits.** The ledger is the operator's private home and CI has none, so an absent shelf reports `SKIP` and
exits 0 — never a redirect and never a false green. The gate is **read-only**: it reports a gap and proposes
a row, but it never renumbers a plan, never rewrites an index row, and never edits a plan (Rule 06). The
rows it proposes take their sentence **verbatim** from the plan's own opening, so a proposal cannot invent a
plan's purpose.

**If it does not work.** `SKIP` means no vault on this machine (expected in CI). A `gap` row names the plan
and the missing item; run `--rows` for the rows, and read the plan before adding a status — the gate reports
what the plan says, and `opened` when it says nothing.

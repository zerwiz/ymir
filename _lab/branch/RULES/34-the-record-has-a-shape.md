# Rule 34 — a record has a shape, and a view is rendered

> Adopted 2026-10-23, after the audit of the scattered record measured the house: 1,312 `.md` in
> the repo and 1,440 in the home, and **not one in ten carrying a header that says what it is**.
> Plan 115 · audit `hodd/docs/audits/2026-10-23-the-scattered-record-audit.md`.

## The law

1. **A document meant to be found again carries the header.** One contract, and it is the one the
   harness already enforces (`.pi/extensions/ymirhome.ts`), extended with two fields:

   ```
   kind          plan | runbook | record | register | index | feature | rule | fix | audit |
                 research | reference | decision | document
   status        live | draft | superseded | archived
   verified      YYYY-MM-DD, or EMPTY — never guessed
   verified_by   the command, the gate or the measurement that proved it
   owner         who answers for it
   tags          a few words that make it findable
   sources       REQUIRED on a research or audit record: the pages behind the claim
   supersedes / superseded_by   the chain that makes a correction possible without an edit
   ```

   A document is **typed** when its first line is `---` and the header carries `kind` and `status`.
   `grade` is written by the grader, never by a hand.

2. **`verified` is a command, not a sentence.** A verification a reader cannot re-run is a memory.
   When the evidence is binary, the record names a `state:` file — and may keep the **hash** of
   evidence it no longer holds (Rule 30 disposes audio; Rule 11 forbids deletion; the hash is how
   both are true at once).

3. **A view is rendered, never hand-appended.** `FEATURES.md`, `RULES/README.md`, `hodd/docs/INDEX.md`,
   `bin/README.md`, `*/DOORS.md` and the library's `INDEX.md` are generated from records. The
   append-only conflict is not a discipline problem — a hand-appended table that main keeps moving
   **must** conflict (measured: two in 24 hours, plan 115 §2).

4. **A derived view must be reproducible and gated, or it is a document pretending to be a
   register.** Render twice into a temp file and diff zero; never read the view as an input to
   itself; sort deterministically; and put its `--check` in `bin/gates/guards.sh` — a gate that
   runs nowhere is a capability that is silently absent (measured: `inventory.sh --check` existed
   and `guards.sh` never called it).

5. **A gate on the diff, not on history.** A *new or changed* document must be typed
   (`bin/records/library.sh check --changed`). The 2,000 documents written before this law are paid
   down shelf by shelf, and a shelf not yet typed is **reported**, never blocked.

6. **A record is corrected by a new record citing the old one** — never by an edit. Nothing is
   deleted to tidy up: a record that cannot be typed is **moved** to `hodd/reference/` with its
   reason (Rule 11).

## Why

Two costs, both measured. **Unfindable**: in a sample of 400 home pages, 175 are named by no index;
four home shelves hold 300+ documents and have no index at all. **Unmergeable**: a hand-appended
catalogue conflicted twice in one day, and both resolutions were *keep both rows* — which is a
ledger pretending to be a table.

## What it costs

A header on every new document: eight lines, once, at creation. That is the whole toll, and it is
paid by the hand that already knows what the document is.

## Enforcement

| gate | refuses |
|---|---|
| `bin/records/library.sh check --changed` | a new or changed document with no header |
| `bin/gates/guards/inventory-guard.sh` | a stale door register |
| `bin/gates/doors.sh --check` | a stale subsystem register |
| `bin/gates/guards/features-guard.sh` | a feature page the catalogue does not name |
| `bin/gates/guards/rules-number-guard.sh` | a rule number used twice, or an index count that is stale |

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

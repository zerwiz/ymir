# Rule 06 — Append-only

Some records are the system's memory. They are **appended to**, never rewritten,
never truncated, never reordered — and **never lost in a move**.

## What is append-only

```
append_only[6]{artifact,why}:
  "$YMIR_HOME/memory/runes_audit.md","the Runes ledger — each entry folds the previous checksum, so a rewritten line breaks every later line"
  "$YMIR_HOME/docs/append-only-log.md","the decision log: what was decided, when, and why"
  "CHANGELOG.md","chronological entries; Brokk appends and never rewrites"
  "RULES/*.md","house law: a rule that contradicts another is changed first, never silently edited"
  "$YMIR_HOME/**","the private record — the operator's hoard, committed to the private git repo, never gitignored"
  "*.jsonl / branch outcomes / session logs","event streams; a re-run is a new file, not a shorter one"
```

## The law

- **Append, never rewrite.** A correction is a **new** entry that cites the old
  one. The old text stays; that is what makes the record trustworthy.
- **Never truncate.** Rotation is a new file with a new name, never a shortened
  one. "It is long" is not a reason to delete a line.
- **Never lose one in a move.** A migration, re-clone, swap or backup **must carry
  every append-only artifact**. They are the part of the system that cannot be
  regenerated from code.
- **Never rewrite shared history to tidy it.** A force-push or history rewrite
  must be weighed against this rule before it happens, not after.
- **A contradiction changes the rule first.** The rules themselves obey this
  rule: append the change, keep the history.
- **Verify by name at the boundary.** Before and after any move, check the
  append-only set explicitly — a move that drops one is a **violation**, not an
  accident.

## The duty at a move

This rule exists because a home swap dropped `docs/append-only-log.md`,
`docs/masterplan.md`, `docs/plans/` and the private business set: the backup
carried `state`, `.env.local`, `data`, the realm and `workspace` — but not
`docs/` or `assets/`. The code arrived; the memory did not.

So the check is explicit, and it is part of the move:

```bash
# the append-only set must exist on both sides of a move
for f in CHANGELOG.md docs/append-only-log.md; do
  [ -e "$f" ] || echo "MISSING append-only artifact: $f"
done
# and the private set must be in YMIR_HOME, not merely in the old home
ls "$YMIR_HOME/docs" "$YMIR_HOME/identity" "$YMIR_HOME/data" 2>/dev/null
```

A backup is only as good as its file list. If a directory is not named in the
backup, it is not carried — and this rule says the append-only and private sets
are always named.

**Related:** `RULES/04-hoard.md` (where private records live), `AGENTS.md`,
`.agents/skills/galdr-ymirsystem/assets/installation.md` (the move procedure).

## Amendment — the changelog writes through fragments (2026-09-17)

Appended, not rewritten; the clause above stands.

**The problem this amendment answers.** `CHANGELOG.md` is one file, and every
branch appends at the same position — the top. Git sees two branches inserting
different lines at the same spot and calls it a conflict, so **every merge
re-conflicts every open branch**. With N branches that is O(N²) conflicts, all of
them meaningless: both entries belong, and neither is wrong. Sixteen open PRs
were each resolved by hand for this reason alone.

**The amendment.** A change tells its story through a **fragment**:

```
CHANGELOG.d/<YYYY-MM-DD>-<slug>.md     the entry, beginning with its `## YYYY-MM-DD — title` heading
```

- **A fragment is a new file with a unique name.** Two branches never touch the
  same one, so the collision cannot occur. This is the whole point.
- **`bin/changelog-assemble.sh` folds fragments into `CHANGELOG.md`** — newest
  first, above everything already recorded. Folding is an **append**: the ledger's
  existing entries are copied verbatim, never reordered, never rewritten.
- **The pre-push hook runs the assembler first**, so the ledger is never behind
  what the fragments already tell. A push that would leave unfolded fragments
  behind is refused with the instruction to commit the fold and push again.
- **The guard accepts either form.** A push satisfies the duty by appending to
  `CHANGELOG.md` **or** by adding a fragment. Appending directly still works and
  is still valid; the fragment is simply the form that cannot conflict.

**Why this obeys the clause above, not contradicts it.** Append, never rewrite —
a fragment is a *new file*, and the ledger only ever grows. Never truncate —
fragments are folded in, never dropped. Never lose one in a move — **`CHANGELOG.d/`
joins the append-only set**, so a move must carry it exactly as it carries
`CHANGELOG.md`. A correction is a new entry citing the old — a fragment may cite;
nothing is edited.

**The append-only set is now:**

```
append_only[7]{artifact,why}:
  "$YMIR_HOME/memory/runes_audit.md","the Runes ledger — checksum-chained"
  "$YMIR_HOME/docs/append-only-log.md","the decision log"
  "CHANGELOG.md","the assembled chronological ledger; folded from fragments, never hand-rewritten"
  "CHANGELOG.d/","pending entries — one file per change; folded in, never dropped"
  "RULES/*.md","house law"
  "$YMIR_HOME/**","the private record"
  "*.jsonl / branch outcomes / session logs","event streams"
```


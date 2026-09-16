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
`.agents/skills/galdr-cli/assets/installation.md` (the move procedure).

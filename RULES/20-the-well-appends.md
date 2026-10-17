# 20 — The well appends: the record is never rebuilt over

**Appended at the Allfather's word, 2026-10-17:** *"the well must always append only."*

The well (Mimirsbrunn — `hodd/memory/kaia.engram`, with its append log
`hodd/memory/well/episodes.jsonl`) is the fleet's memory of what was learned. A lost
episode is a lesson paid for twice: the machine re-makes the mistake and no one knows
it was already known.

```
well_law[4]{rule}:
  "APPEND, never replace","an episode is written once and stays. A store is never rebuilt, regenerated, recovered-over or resynced in place."
  "A SECOND TRUTH IS A LOSS","when two wells fork, the merge is a UNION — every record from both is appended. `resync` on a well means append, never overwrite."
  "REPAIR ADDS, IT DOES NOT SUBTRACT","a corrupt store is preserved exactly as found and recovery APPENDS beside the live one; what cannot be read is recorded as a known gap, never silently."
  "THE COUNT NEVER FALLS","the episode count and the log's line count are monotonic. A run that lowers either is a failure, not a tidy-up."
```

**What the law permits, and what it forbids:**

- **Permitted:** appending an episode; appending a fork's missing records; restoring a
  lost episode from git or another seat's copy (with provenance tags); annotating an
  episode (a tag) without touching its content; removing an episode from the *derived*
  index (a vector, an FTS row) while the record stays.
- **Forbidden:** deleting an episode; rebuilding the store from a subset; restoring an
  older snapshot *over* a newer one; `git checkout` of the binary store over a live one;
  a "merge" of two stores that picks one.
- **Not the well's law, but its company:** the store is binary, so git cannot merge it.
  The **log** is the truth and the log is text (Rule 06, append-only). A seat unions the
  log; the engram is *derived* and is never `git merge`d.

**Why this rule exists — the incident it answers (2026-10-07, found 2026-10-17):** a
malformed store (`btreeInitPage() error code 11`) was preserved, then salvaged with
`sqlite3 .recover`, which could only keep the pages it could read: **134 episodes
became 98, and 36 were lost.** 16 were later restored from git; 20 (2026-10-04..06)
existed nowhere else. Nothing noticed — the store had shrunk by a third and the loss
rode the vault for ten days, because there was no ward watching the count.

**Enforced by:** `bin/records/well-guard.sh` — `check` fails when the episode count or
the log's line count falls below the recorded checkpoint, when an episode's content is
empty or the literal string `undefined`, or when an episode has no vector (in the record
but invisible to recall). `record` rolls the checkpoint forward after a passing check;
Eir composes it as the `well` surface, so a loss is reported the next time anyone
diagnoses the house. `well-guard.sh --self-test` proves the ward bites.

# MIMIRSBRUNN — Vector Memory & Audit Ledger

Long-term memory and the system audit trail for **this machine**.

## What is tracked here, and what is not

The well is **per-machine**. It is "one repo-local store shared by every agent"
on *this* host — never shared between hosts or users. A fresh clone must start
empty and build its own memory; it must never inherit someone else's.

```
memory_contract[5]{path,tracked,why}:
  "README.md","yes","this contract — the only file that belongs in git"
  "kaia.engram","NO","the store: this machine's private memory (gitignored)"
  "kaia.engram-wal / -shm","NO","SQLite volatile sidecars; a stale WAL can corrupt a fresh clone"
  "well/*.jsonl","NO","the append log: the same per-machine data"
  "runes_audit.md","careful","append-only ledger; see the note below"
```

`.gitignore` enforces this (`.agents/memory/kaia.engram*`, `*.db`, `well/*.jsonl`).
If a file here is tracked and mutates at runtime, that is a bug: it dirties every
checkout and leaks one machine's data to every other.

**Rebuilding the store.** The JSONL log is the source of truth for re-seeding;
`bin/mimir-ingest.sh` drinks a directory into it. A new machine starts with no
store and fills it as it works — that is correct, not a failure.

## Audit ledger note

`workspace/memory/runes_audit.md` is the append-only Runes ledger. It is tracked
because the audit trail is part of the record, but it is written by every machine
that runs Ymir. When two machines both append, the checksum chain diverges. The
law: **one writer per ledger.** If a merge would fork the chain, keep the
canonical chain and preserve the other side as a `state/*.bak` file rather than
interleaving entries.

## Files

- `kaia.engram` — the store (episodes, facts, entities, edges). Per machine.
- `well/*.jsonl` — the raw episode log (source of truth for re-seeding).
- `runes_audit.md` — the append-only audit ledger (see the note above).

## Memory Tiers

1. **Hot** — `svartalfaheim/<realm>/workspace/*.md`
2. **Deep** — the engram store, indexed from workspace changes

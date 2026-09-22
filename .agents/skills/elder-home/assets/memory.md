# The memory charter (assets of the elder skill · Reginn)

A true elder remembers — so memory is kept true, one record, append-only.

## The well (Mimirsbrunn)

- **One store:** `$YMIR_HOME/hodd/memory/kaia.engram` (+ the checkpointed
  episodes/runes in the same shelf). Plan 37's law: the well rides the home;
  each seat's vector index is DERIVED from it (a rebuild task), never shipped
  by WAL. Plan 42's live lane: bodies recall via MCP from the heart's store.
- **Recall before act:** the orchestrator reads the well before dispatch, and
  honours the anti-hallucination gate.
- **Observe after lessons:** a run that teaches something durable is written
  plain and true (actors, content, salience, tags).

## The runes ledger

- **Append-only JSONL under a markdown head**, chained by checksum — a line
  cannot change without breaking every later line. Never rewrite, never
  truncate, never lose in a move.
- **Single canonical writer on the heart** (plan 42 target). Bodies append via
  the chain; a fork is healed by a NEW entry carrying both tails (never a
  silent merge). The 2026-09-22 fork-and-hand-merge is the cautionary tale.
- Every significant action is carved: `bin/runes-append.sh <actor> <event>
  --realm R --message "…"` (or the home's ledger via `BROKK_HOME`).

## Daily logs

- `$YMIR_HOME/hodd/memory/daily/YYYY-MM-DD.md` — one per day, dated, appended.
  A daily log is never rewritten; a correction is a new entry citing the old.

## Housekeeping

- Memory housekeeping (Nornir 00:30) prunes nothing from the record — it backs
  the engram and reports honestly (`engram=absent` is a fact, not a fix).
- Telemetry/observability touches (`observe`) do not pollute the ledger;
  observations belong in the well, decisions belong in the runes.

## Memory in the ledger of plans

The plan ledger and the memory well are different records: plans say what was
DECIDED (with the elders holding continuity); the well says what was LEARNED;
the runes say what was DONE. The elder keeps all three coherent — a plan cites
its elders, an observed lesson cites its runes.
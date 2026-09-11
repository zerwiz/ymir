# MIMIRSBRUNN — Vector Memory & Audit Ledger

Long-term memory, vector store, and system audit trail.

## Planned Files
- `mimirsbrunn.db` — vector embeddings (LanceDB / SQLite-vec)
- `runes_audit.md` — append-only system audit ledger

## Memory Tiers
1. **Hot** — `svartalfaheim/<realm>/workspace/*.md`
2. **Deep** — vector embeddings indexed from all workspace changes
## agents · 2026-10-22 — the ledger survives, a spoken answer is one clause, and a Swedish question is answered in Swedish

Four of the audit's owed items, each measured before it was written.

```
fixed[4]{item,was,now}:
  "his ledger died with the disk","`hodd/state/` is gitignored; 372 conversations, no copy anywhere","`backup.sh` snapshots `assistant.db`, `asks.json`, the digest and the identity shelf into `hodd/saves/assistant/<date>/` (tracked), rotates to 7, and has a nightly row at 03:20 — `--commit` stages it, which stays the Allfather's call"
  "no retention window","third-party text lived forever, with no deletion path","`prune.sh --days N` prints what would go and changes NOTHING unless `--apply` — the decision is one command away, not a promise"
  "a list was read aloud","a voice answer could be thirty slugs","a spoken answer is compressed to one clause: *'I hold 21 approved facts — and 24 more, which I can read one at a time.'*"
  "every answer was English","his clients and his calendar are Swedish","`language_hint()` — two or more Swedish markers and the mouth is told *Answer in Swedish*; measured: *'OptiCat är ett system för den statliga svenska ventilationssynen (OVK)…'*"
```

**Also in this pass:** research announces itself in a call — *"One moment, I'm looking."* — before the
provider call, because 2.5–4 s of silence against a 1.2 s bar reads as deafness; and retrieval may now
return a **set** of near-equal facts (up to three) so the model can join two approved facts instead of
answering from one.

**Verified:** `walls-test` holds — including *"a list is compressed into one spoken clause"* and
*"a Swedish question is marked for a Swedish answer"* · `research-smoke` 17/17 · `backup.sh` wrote
4 files + the identity shelf · `prune.sh --days 90` reported 0 of 422 rows old, and changed nothing.

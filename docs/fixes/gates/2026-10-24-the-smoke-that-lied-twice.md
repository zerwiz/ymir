# The smoke suite that lied twice — and the cron leak it caught

**2026-10-24.** Components: `.agents/skills/lifecycle/smoke_test.sh`, `bin/engine/ymir-validate.sh`,
`bin/agents/eir-doctor.sh`, the per-seat Nornir loops.

Run before the night's build work: **49 OK · 8 SKIP · 1 FAIL**, and that one is external (Trello's MCP refuses
`initialize`). Getting there meant fixing four things the suite itself was wrong about, plus one real leak.

## The suite was wrong twice

1. **`rename-sweep` flagged `hodd/workspaces`** — a shelf that exists and holds real material (aizerwiz ·
   meetings). The rename it means is `svartalfaheim/<realm>/workspace/` → `projects/` and the retired flat
   `workspace/` in the repo. Naming the home's own shelf made the suite red for code that was right.
2. **`hardcoded-paths` flagged a comment.** The last hit was prose in `eir-doctor.sh` quoting an absolute home to
   describe a past fault. Reworded, because a rule that trips on its own explanation teaches people to ignore it.

## One real stale reader, found behind them

`bin/engine/ymir-validate.sh` still listed `$ROOT/workspace/memory/runes_audit.md` as a fallback location for the
ledger — a path retired by `0001-hoard-layout`. It now tries the hoard's two spellings only (Rule 06: the ledger
follows the hoard).

## And one real leak the suite caught properly

`cron-leak: 6 cron loops running — ended seats left schedulers behind`. True: **every errand seat started its own
Nornir loop from the house's `config/cron.yaml`**, with its own stamp dir — so five errand seats plus the main one
were all reading one schedule and each keeping its own "already fired today" marks. That is not just wasted
processes: a job due at 14:20 could run six times, once per seat, with each scheduler believing it was the first.

**Fixed for now:** the five per-seat loops were terminated; the main scheduler is the only one, and the suite is
back to `2 cron loop(s)` (the main plus the checker's own transient).

**Owed, and it is the durable fix:** a seat must not start the house scheduler at all — the seat's role gate should
refuse a schedule it does not own, or the spawn should pass an empty config. Killing the loops treats the symptom.

## The well was up and broken

`well: FAIL — bridge not answering` while `mimir-bridge.sh --start` said *already up*: the process was listening on
`:4602` and answering **HTTP 500**, and `mimir.sh health` reported **COLD**. A restart brought it to `200` and
`WARM, 151 entries, online`. A port that answers is not a door that works.

## Final state of the suite

```
smoke: 49 OK · 8 SKIP · 1 FAIL
the one FAIL: mcp:trello — initialize failed (https://mcp.trello.com/v1) — an external door, needing its own grant
```

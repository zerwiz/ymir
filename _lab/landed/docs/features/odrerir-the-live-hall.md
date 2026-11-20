# Óðrerir — the live hall

## What it is

**Óðrerir** is the fleet's **live hall board**: a glass showing what is happening —
tasks, panes, and the record — updated as it goes. It is a planning surface, not a
control plane: you look at it (Hlidskjalf is the seat you *act* from).

## What you need

- Ymir installed; the board app (`apps/odrerir`) and its snapshot feed.

## Do it

The board is served on **:4322**. Its data comes from the **snapshot feed**:

```bash
systems/snotra/services/cron/hall-snapshot.sh        # writes the live-hall snapshot
bin/time/nornir-job-hall-snapshot.sh    # the scheduled job that refreshes it
```

The snapshot lands at `apps/odrerir/public/livehall.json`, which the board reads.

## Notes and limits

- **It reads; it does not act.** The hall is observation. Actions go through the engine
  and Hlidskjalf.
- **The snapshot is the source.** If the board is stale, the feed is stale — check the
  scheduled job.
- **One hall per seat/library**, fed by the same snapshot shape.

## If it does not work

| What you see | What to do |
|---|---|
| The board is empty or stale | Run `systems/snotra/services/cron/hall-snapshot.sh`; check the Nornir job is firing (`bin/time/nornir-cron-start.sh --status`). |
| `:4322` refuses | The board app is not raised — raise the hall (`scripts/start.sh` raises the set). |
| The MCP face fails | `bin/desktop/odrerir-mcp-smoke.sh` — the smoke test names the fault. |

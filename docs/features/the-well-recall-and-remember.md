# The well — recall and remember

## What it is

**Mimirsbrunn** is Ymir's long‑term memory — the well. It is one store, in the hoard,
that remembers what happened and hands it back when it matters: **drink before you
act, water it after.** Every session can recall decisions, and record what it learned,
so the next session starts smarter than the last.

## What you need

- Ymir installed. The memory engine (engram) is provisioned by the installer /
  `bin/engine/prereq-ensure.sh engram`.

## Do it

```bash
# is the well reachable?
bin/records/mimir.sh health
```

**Recall** — ask before you act:

```bash
bin/records/mimir.sh recall "why did we stop using the old model rail" --k 5
bin/records/mimir.sh recall "vault key design" --mode hybrid   # hybrid | cosine | spreading
```

**Record** — water it after:

```bash
bin/records/mimir.sh observe "Mjollnir never force-merges; Glitnir holds the seal" --tags mjollnir,gate
```

**Walk the timeline** — a thing's history, in order:

```bash
bin/records/mimir.sh timeline --entity vault
```

### The bridge (so agents can recurse)

The engine lives behind a bridge on `:4602`; agents reach it as the `engram` MCP
(recall/observe) rather than shelling out:

```bash
bin/bridge/mimir-bridge.sh --start     # raise the bridge
```

## Notes and limits

- **One well, and it lives in the hoard.** The store is
  `$YMIR_HOME/hodd/memory/kaia.engram` — never in the code tree (Rule 04). Everything
  resolves it through `bin/vault/hoard-lib.sh`.
- **Recall is not authority.** The well returns what was *recorded*; if it conflicts
  with the code or the operator, the code and the operator win. The well is memory,
  not law.
- **Nothing confidential is watered in.** Vault content never enters the well (Rule 15)
  — a confidential session points `ENGRAM_DB` at the session, not the well (Rule 16).
- With the bridge up, agents should prefer the MCP tools; `mimir.sh` is the same well
  from the shell.

## If it does not work

| What you see | What to do |
|---|---|
| `health` fails | Raise the bridge: `bin/bridge/mimir-bridge.sh --start`; check the engine is provisioned with `bin/engine/prereq-ensure.sh status`. |
| Recall returns nothing | The well is young, or nothing matched — observe a few facts first, or widen `--k`. |
| An agent cannot recall | The `engram` MCP is not wired for its harness — re‑run the memory surface: `bin/agents/eir-doctor.sh fix` (the `well`/`mcp` surfaces). |

# Ratatoskr — agent-to-agent (A2A)

## What it is

**Ratatoskr** is the squirrel that runs the world‑tree: Ymir's backbone for
**agent‑to‑agent** work on the open **A2A** protocol. Every agent publishes an **Agent
Card**; discovery is by capability; tasks have a lifecycle; and messages stream. Redis
is the queue *under* it; A2A is the semantics.

## What you need

- Ymir installed; the A2A engine (`a2abridge`) present — the bridge ensures it.

## Do it

```bash
bin/bridge/ratatoskr.sh status            # engine + directory health + served agents
bin/bridge/ratatoskr.sh directory start   # the local discovery daemon (:7777)
bin/bridge/ratatoskr.sh doctor            # the engine's full health-check
bin/bridge/ratatoskr.sh cert …            # an ed25519 cert+key for cross-machine federation
```

The **Agent Card** is served at `/.well-known/agent-card.json` (the heart's node on
`:8301`). Agents reach the A2A tools through MCP (`a2abridge`), wired by
`bin/bridge/a2a-mcp.sh` — the engine never edits IDE configs itself.

## Notes and limits

- **The engine is the authority.** `a2abridge` (MIT) is the engine; `ratatoskr.sh` is a
  fail‑safe Ymir‑shaped wrapper. The mesh Ymir calls Ratatoskr is the same wire.
- **Every message is observed.** A2A traffic lands in **Mimirsbrunn** and in **Runes**.
- **Local directory by default.** `:7777` is the local discovery daemon; multi‑machine
  federation needs a cert and the tailnet — see the fleet page.
- **Not the whole story yet.** The *directory of many installs and per‑pair grants* is a
  planned phase; the native backbone answers today.

## If it does not work

| What you see | What to do |
|---|---|
| `status` shows the directory down | `bin/bridge/ratatoskr.sh directory start` (or `service`). |
| No A2A tools in a harness | `bin/bridge/a2a-mcp.sh install`, then re‑bind the harness. |
| A peer cannot see you | Federation needs the cert + the tailnet; check `cert` and your tailnet. |

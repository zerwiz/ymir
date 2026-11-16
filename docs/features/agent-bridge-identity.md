# The bridge identity — every session's A2A card names itself

## What it is

Every session that speaks A2A spawns a bridge, and the bridge publishes a card. Before this,
every bridge on a machine was spawned identically: same name, same id, same state directory,
and `127.0.0.1` as its address. Two sessions on one box fought over a port, shared one inbox,
and every card claimed to be a `brokk` on loopback.

`bin/bridge/a2a-bridge-session.sh` resolves the identity from the session's own environment:

| what | from where | example |
|---|---|---|
| harness | `A2A_HARNESS`, else the session's environment, else `unknown` | `pi`, `claude`, `hermes` |
| pane | `HERDR_PANE_ID` | `w6R:p1` |
| name and id | `<harness>-<pane>` | `pi-w6R-p1` |
| address | the fleet registry's name for this machine | `<machine>.<tailnet>.ts.net` |
| port | the first free one from `A2A_PORT`, reserved atomically | `8391` |
| state | one directory per session | `…/state/pi-w6R-p1` |

## What you need

- `a2abridge` installed (it is the engine; this is the wrapper).
- Nothing else: it is seated by `bin/bridge/a2a-mcp.sh install`, which install and every
  update run.

## Do it

See who a session's bridge would be:

```bash
bin/bridge/a2a-bridge-session.sh --identity
```

See exactly what it would run, without claiming a port:

```bash
bin/bridge/a2a-bridge-session.sh --dry
```

In normal use you never call it: the harness's MCP entry does, once per session.

## Limits

- One session, one bridge, one port. A box that exhausts the span says so rather than
  silently sharing.
- A harness that cannot be named is `unknown`, not guessed. Give it `A2A_HARNESS` if it has a
  name worth publishing.
- On a box that is not in the fleet registry, the address is loopback, because that is the
  truth there. A card that names an address nobody can dial is worse than one that admits it.
- A port claim whose process is gone is released on the next start, so a crashed session does
  not use up the span.

## If it does not work

- `no free port in 8391..8431 after sweeping dead claims` — genuinely every port is held by a
  live bridge. Close one, or raise `A2A_PORT`.
- A card still names `127.0.0.1` on a fleet seat — the fleet registry has no entry for this
  machine's hostname. `bin/fleet/roads.sh check` shows what the registry knows.
- Two sessions share one inbox — check `--identity`; if the ids match, the panes do too, and
  one of the sessions is running in another's pane.

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 6).

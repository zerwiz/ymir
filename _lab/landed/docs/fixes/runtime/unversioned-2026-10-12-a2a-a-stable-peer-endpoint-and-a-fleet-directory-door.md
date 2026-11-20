## runtime · unversioned · 2026-10-12 — A2A: a stable, reachable peer endpoint, and a fleet directory door (ticket ymir/54)

### What

Ratatoskr's A2A bridge answered on a **loopback, random** port while advertising the
**tailnet IP** — so a card named an address **no peer could reach**, and the port
changed every run, so a card could never name it. Two changes fix the two smallest of
the four gaps in ticket **ymir/54**:

1. **A stable, reachable bind — `bin/bridge/a2a-mcp.sh`.** When the bridge is wired
   into a harness it is now started with `-bind <tailnet-ip>:8391` (`A2A_PORT`,
   default `8391`; `A2A_BIND` overrides) and `-advertise-host <tailnet-ip>`, instead
   of the default `-bind 127.0.0.1:0`. A peer service binds where peers can reach it;
   with no tailnet it falls back to loopback, honestly.
2. **A fleet directory door — `bin/bridge/ratatoskr.sh agents`.** The local a2abridge
   directory lists only *this* seat. `ratatoskr agents` probes **every online tailnet
   peer** on the stable port and prints the A2A cards that answer, so a Brokk can see
   the fleet's peers instead of guessing URLs.

The remaining gaps — cards naming the endpoint (not the portal) and per-pair grants —
are the next increment of **plan 61 §1**.

### Verified

- `bash -n` clean on both; `a2a-mcp.sh show` still parses (`a2abridge yes/yes`).
- `ratatoskr agents` runs and reports honestly when no peer answers on `:8391`
  (`a2a-agents[0]{…} "none"`) — the live bridges are still on their old dynamic ports
  until each seat re-wires; this is the ground for them to land on.

### Files

- `bin/bridge/a2a-mcp.sh`
- `bin/bridge/ratatoskr.sh`
- `bin/gates/guards/fixes-guard.sh` (map the a2a scripts to the `runtime` component)

## runtime · unversioned · 2026-09-25 — the mesh spoke a tongue the engine no longer had

### Why
The Allfather asked whether the A2A mesh was connected and functional. Half was:
the heart's node answered, the MCP doors were reachable. This repair names the
two faults that kept it from being a mesh, and mends both.

- **The wrappers parsed a shape the directory stopped returning.** `a2abridge`
  **3.0.0** answers `GET <directory>/agents` with a **bare list of
  `{url,lastSeen}`**. `bin/a2a-talk.sh` and `bin/ratatoskr.sh` still fetched the
  directory **root** (`$DIR/`) and parsed `{served_agents:[{name,url,local}]}` —
  an older engine's shape. Result: `directory unreachable` from `a2a-talk agents`
  and `agents: ?` from `ratatoskr status` while the daemon was healthy — a check
  that lied in the same family as the tree-`state/` decoy of the same day.
  Both now read `/agents`, and `a2a-talk` resolves a peer's **display name from
  its card** (`<url>/.well-known/agent-card.json`), since the listing carries no
  name; a peer may also be passed as a full URL.
- **The heart's card advertised a LAN address.** `tools/ratatoskr-node/server.ts`
  hardcoded `url: \`http://192.168.68.111:${PORT}/\``. A peer resolving the card
  off-LAN is sent to a dead door — the exact Rule 07 fault the architecture plan
  names (“a fleet MCP is addressed by tailnet name, never a LAN IP”). The card
  address is now **resolved, not hardcoded**: `A2A_ADVERTISE_URL` wins, then
  `A2A_ADVERTISE_HOST`, then this host's own tailnet DNS name (`tailscale status
  --json` → `Self.DNSName`), then loopback.
- **Proved live:** the engine installed and the directory service raised on both
  seats; the heart's card now reads
  `http://whynot.tailefab81.ts.net:8301/` over the tailnet, and
  `bin/a2a-talk.sh agents` / `bin/ratatoskr.sh status` report the true directory.
- **One fault named, not fixed:** on the heart (whynot) `bin/a2a-mcp.sh` printed
  `YMIR_HOME: unbound variable` at line 56 — the seat's checkout still wants the
  one-resolver preamble. It did not block the wiring, but the heart runs a stale
  tree and should be pulled.

galdr-reread: `ratatoskr-a2a` (the mesh skill: the raw directory shape and the
card address).

### Files
- `bin/a2a-talk.sh`
- `bin/ratatoskr.sh`
- `tools/ratatoskr-node/server.ts`

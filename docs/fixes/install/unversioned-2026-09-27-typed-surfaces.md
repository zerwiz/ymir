## install · unversioned · 2026-09-27 — typed surfaces: one A2A contract, the first servers under packages/

### Why
Plan 58 Phase 6 (`58-codebase-and-architecture-deepening.md`): the MCP/A2A
servers are the fleet's served doors, but they lived in `tools/` with their wire
shapes restated in every consumer. Moving them under `packages/` is the seam;
sharing ONE typed contract is what makes the move honest — a server and its UI
must compile against the same shape. Done as a strangled move: a served door and
its unit name never change, so the live record faces (`:8317`–`:8320`, now
serving from the heart) must not blip.

### What
- **`packages/contracts/`** — `@zerwiz/contracts`: the A2A 1.0 agent-card
  contract (types + a runtime validator), dependency-free so it compiles in both
  consumers and runs under node/bun/the browser bundle. A card that leaves the
  shape throws `AgentCardContractError` **naming the field** (`skills[0].id`,
  `capabilities.streaming`, …). Contract tests live in `packages/contracts/test/`.
- **The A2A node moved** `tools/ratatoskr-node/server.ts` →
  **`packages/a2a/ratatoskr/server.ts`**; its card is built through the shared
  contract in **`packages/a2a/ratatoskr/card.ts`**. The card's url is resolved at
  runtime from the hoard's fleet registry (the seat's own row: LAN, then
  tailnet) — the heart's LAN address is no longer baked into the repo, and
  `A2A_AGENT_NAME` / `A2A_CARD_URL` / `YMIR_HOST` override it. Unit
  `ratatoskr.service` and door `:8301` are unchanged; only `ExecStart` is
  repointed to `packages/a2a/ratatoskr/server.ts`.
- **The first MCP server moved** `tools/skills-mcp/server.mjs` →
  **`packages/mcp/skills/server.mjs`** (Bölþorn). It is a deps-free stdio MCP
  server; unit `skills-mcp.service` and door `:8319` are unchanged; only the
  `ExecStart` path is repointed.
- **The contract's second consumer is Hlidskjalf** —
  `apps/hlidskjalf/src/types.ts` imports `AgentInterface`, and the gate builds
  the same shape in `apps/hlidskjalf/server/index.ts`.
- **Deployment / packaging** — `bin/fleet/fleet-ensure.sh` and `bin/fleet/fleet-deploy.sh`
  copy a DIRECTORY row whole, preserving the `packages/` anchor, so a relative
  import across packages resolves in the deployed `~/.fleet` copy exactly as in
  the repo. `bin/forge/npm/npm-pretest.sh`'s hull and `package.json` `files[]` carry
  `packages/`.
- **The proof is a gate** — `bin/gates/checks/contracts-check.sh` (tests + contract tsc +
  A2A-server tsc + Hlidskjalf tsc), wired into `bin/gates/ci-verify.sh`.

### Still standing (strangler, stated plainly)
Five servers remain in `tools/` and move in later PRs: `well-mcp`
(`tools/well-mcp/server.ts`), `tickets-mcp`/Skuld (`tools/tickets-mcp/server.mjs`),
`snotra` (`tools/snotra/server.mjs`), `mcp-gateway`
(`tools/mcp-gateway/server.mjs`), and the mill worker (`tools/mill/worker.sh`).
Their doors and unit names are untouched here.

### Files
- `packages/contracts/{package.json,tsconfig.json,src/agent-card.ts,src/index.ts,test/agent-card.test.ts}`
- `packages/a2a/ratatoskr/{server.ts,card.ts,tsconfig.json}`
- `packages/mcp/skills/server.mjs`
- `bin/fleet/fleet-ensure.sh` · `bin/fleet/fleet-deploy.sh` · `bin/forge/npm/npm-pretest.sh` · `bin/gates/checks/contracts-check.sh` · `bin/gates/ci-verify.sh`
- `tools/mill/systemd/ratatoskr.service` · `tools/mill/systemd/skills-mcp.service`
- `apps/hlidskjalf/src/types.ts` · `apps/hlidskjalf/server/index.ts`
- `package.json`
- `.agents/skills/galdr-ymirsystem/assets/{harness-integration/README.md,registry.md,installation.md,hlidskjalf-ui.md}`

### Proof
- `node --test packages/contracts/test/` → pass 4, 0 fail · the deliberately
  mismatched card is refused by name.
- `bash bin/gates/checks/contracts-check.sh` → all 4 legs PASS.
- The moved MCP server still serves its door: `initialize` → `tools/list`
  answers (`skills-mcp`, `load_skill`) on the moved file.
- `bin/bridge/mcp-gateway.sh resolve` still yields `bolthorn` `:8319` — no door moved;
  `bin/bridge/mcp-gateway.sh catalog` still resolves.
- `apps/hlidskjalf` `tsc --noEmit` green; `bun build apps/hlidskjalf/server/index.ts`
  resolves the contract import.

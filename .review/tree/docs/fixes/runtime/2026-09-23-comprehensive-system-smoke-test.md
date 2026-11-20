## runtime · unversioned · 2026-09-23 — a full-system smoke test, MCP connections included

### Why
- **Problem:** the lifecycle smoke test (`smoke_test.sh`) checked five surfaces
  (SPA, gate API, well, Smiðja DB, loaders). It never touched supervision, cron,
  migrations, the vault, the ledger, the toolchain, the delivery gate — and it
  never proved an **MCP connection**. So it reported a green board while
  supervision flapped, cron had leaked eight orphan schedulers, the hoard had
  drifted, and the ticket/plan MCP (`skuld`) was dead.
- **Also found:** the test sourced `hoard-lib.sh` from its own skill tree
  (`.agents/skills/…`), so `ymir_home_root` was undefined and it printed
  `ymir_home_root: command not found`; and its cron/migration checks resolved the
  **code-tree** state, not the operator's, so a running cron read as stopped.
- **Fix:** a comprehensive, tolerant smoke test — 35 checks across four layers:
  - **services** — SPA, gate API, well, Bifrost, Smiðja API/UI, hall, model rail
  - **runtime** — session lock, lock pointer (names this machine's home),
    supervision (watcher heartbeat), harness bindings, agent loaders, cron +
    cron-leak, structure migrations
  - **data** — Smiðja schema, the well store, the hoard layout, the vault + age
    key, the audit ledger, the fleet backlog
  - **integrations** — every configured **MCP server completes a real handshake**
    (`initialize` → `tools/list`, reporting the tool count), firecrawl, A2A, herdr,
    the one-local-model lock, node, the pi model registry, and the pre-push gate
  - **governance** (deep) — compliance gates and the secret ward
- Optional surfaces (Bifrost without a key, an idle model rail, a stdio MCP, an
  unraised dev UI) report **SKIP**, never FAIL; every check is independent.
- `bin/npm-install-local-test.sh` is the companion real-install gate (PR #150).

### Files
- `.agents/skills/lifecycle/smoke_test.sh`

### Findings it now surfaces on this box
- `cron-leak` FAIL — 8 orphan cron loops from ended seat sessions.
- `hoard` FAIL — flat `data/` beside `hodd/`.
- `mcp:skuld` FAIL — the ticket/plan MCP does not complete `initialize`.

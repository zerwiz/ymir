## runtime · unversioned · 2026-10-08 — the halls bind loopback only

### Why
The security sweep (2026-10-08) found two Ymir-raised doors answering
without a key on every interface: the well's MCP face (`mcp-proxy` on
`:8317`, `--host 0.0.0.0`) and the Smíðja visualizer API (`:8437`, Bun's
default all-interface bind). Both are local tools — nothing remote calls
them — and this seat has no firewall, so their 0.0.0.0 binds were LAN-open.

### Mend
- `tools/mill/systemd/well-mcp.service`: `--host 0.0.0.0` → `--host 127.0.0.1`.
- `apps/smidja-factory/apps/visualizer/server/index.ts`: `Bun.serve` now
  takes `hostname: HOST` where `HOST` defaults to `127.0.0.1` (env-overridable
  per Rule 07); `tools/web/systemd/smidja.service` seats `HOST=127.0.0.1`.
- The gate's key: seated in the HOME's `.env.local` (the unit's
  `__YMIR_ENV_FILE__` resolves there) — the code default never rides.

### Proven
- `ss -tlnp`: both doors now bind `127.0.0.1` only.
- Gate: login with the seated key → 200; anonymous → 401; the gate process
  env carries the key.

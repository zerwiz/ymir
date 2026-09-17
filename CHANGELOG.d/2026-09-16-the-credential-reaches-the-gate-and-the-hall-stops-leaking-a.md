## 2026-09-16 — the credential reaches the gate, and the hall stops leaking an IP

Setting the operator password had **no effect**. This is the bug that made that
true, and the runtime state that leaked a private address.

- **`scripts/start.sh` never loaded the platform env for the gate.** The gate is
  `bun run apps/hlidskjalf/server/index.ts`, and the server reads
  `process.env.HLIDSKJALF_AUTH` — but the launcher passed only `PORT`, and nothing
  sourced `.env.local`. So a credential written by `bin/ymir-setup-auth.sh`
  (correctly: `0600`, gitignored) never arrived, and because the gate treats an
  empty `GATE_AUTH` as authenticated (`authed: GATE_AUTH ? … : true`) the gate
  stayed **open**. `start.sh` now loads `.env.local` once, before the ports, for
  every service it raises — the gate, Bifrost and Mimir.
- **`apps/odrerir/.astro/dev.json` was tracked.** Astro rewrites it on every
  start with the live `pid` and the host's own addresses (LAN + tailnet) — a
  private-IP leak into a public tree. It is now untracked and gitignored; the
  generated types beside it stay tracked.
- `galdr-reread`: `assets/hlidskjalf-ui.md` (the gate must receive the credential)
  and `assets/odrerir-hall.md` (`.astro/dev.json` is runtime state).

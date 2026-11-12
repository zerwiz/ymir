## hlidskjalf · unversioned · 2026-11-12 — the Nornir board reads its server seats from the fleet registry

### Why

`/api/cron/seats` asks each server seat for its loop over ssh. Its default list was two machine names written
into `apps/hlidskjalf/server/index.ts`. That is a leak in a public repository (RULES/04, RULES/39), and an
assumption no other operator's fleet shares: on any other fleet the board asked two machines that do not exist
(plan 278, problem 39).

### What changed

`apps/hlidskjalf/server/server-seats.ts` resolves the list:

1. `YMIR_CRON_SERVER_SEATS="seat:sshhost …"`, the operator's explicit word, as before;
2. else the fleet registry (`YMIR_FLEET_REGISTRY`, or `<hoard>/data/fleet.json`): every host whose roles include
   `heart` or `forge`, other than this machine, with the registry's name as the ssh host;
3. else no server seats, and the board shows only its own loop.

The server calls it; no seat is named in the code.

### What was not changed, on purpose

The route's shape, its BatchMode ssh round-trip and its three-second timeout are unchanged. A seat that reached a
server through an ssh alias that differs from the registry name sets `YMIR_CRON_SERVER_SEATS`.

### Proof

`node --test apps/hlidskjalf/server/server-seats.test.ts` (and `bun test`) — 6 pass: heart and forge hosts are the seats; this
machine is excluded; no registry is no seats; the explicit list wins; the registry under the hoard is the
default road; the server code names no seat of its own. `bun build` of `server/index.ts` succeeds.

### Files

- `apps/hlidskjalf/server/server-seats.ts`
- `apps/hlidskjalf/server/server-seats.test.ts`
- `apps/hlidskjalf/server/index.ts`
- `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`

## CHANGE LOG

- **2026-11-12** — Opened.

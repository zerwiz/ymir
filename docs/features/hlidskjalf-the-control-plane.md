# Hlidskjalf — the control plane

## What it is

**Hlidskjalf** is Ymir's dashboard — Odin's high seat. It is where you *see* the
system: the workspaces, the runs, the record, the fleet — over one page instead of a
dozen terminals. The **gate API** behind it enforces auth, so the portal is the single
way in.

## What you need

- Ymir installed (`install.sh` / `bin/engine/ymir-install.sh`).
- Nothing else for local use; a browser on the same machine.

## Do it

```bash
# raise the whole system (portal, gate API, cron, bridges, visualizer)
scripts/start.sh
```

That brings up:

| Surface | Address |
|---|---|
| Hlidskjalf SPA | `http://127.0.0.1:3888` |
| Gate API (auth + `/api/*`) | `http://127.0.0.1:3889` |

Open **http://127.0.0.1:3888** in a browser. The first time, the gate shows an
**in-app login** — your credentials come from `HLIDSKJALF_AUTH` in the home's
`.env.local` (never inline, never in the repo).

```bash
scripts/stop.sh          # lower it all again
```

### Let someone else in

```bash
bin/engine/ymir-invite.sh            # mint an invite code (idempotent)
bin/engine/ymir-invite.sh list       # what is live and what is spent
```

Hand the code over; the person registers with it.

### Reach it from another machine

```bash
bin/forge/gjallarhorn-tunnel.sh start   # Cloudflare tunnel → the gate (:3889)
```

The tunnel exposes the **gate**, so auth still stands between the network and
anything private.

### The desktop shell

```bash
scripts/electron.sh start                 # an Electron window over Hlidskjalf
scripts/electron.sh start --view smidja   # …or the Smiðja visualizer
scripts/electron.sh stop | status
```

## Notes and limits

- **Local by default.** SPA `:3888` and gate `:3889` bind loopback; the tunnel is opt‑in.
- **Auth belongs to the operator.** There is no baked‑in name; the in‑app login uses
  `HLIDSKJALF_AUTH` from `$YMIR_HOME/.env.local`.
- **One control plane.** Other surfaces (Óðrerir, Smiðja) are their own apps, but
  Hlidskjalf is the seat you actually look at.
- Ports are configuration (Rule 07): `HLIDSKJALF_PORT`, `HLIDSKJALF_API_PORT`.

## If it does not work

| What you see | What to do |
|---|---|
| Nothing on `:3888` | `scripts/start.sh` and watch its output; check `scripts/start.sh --help`. |
| The login rejects everyone | Set `HLIDSKJALF_AUTH` in `$YMIR_HOME/.env.local`, then restart. |
| Another machine cannot reach it | Start the tunnel (`bin/forge/gjallarhorn-tunnel.sh start`); confirm auth is set first. |

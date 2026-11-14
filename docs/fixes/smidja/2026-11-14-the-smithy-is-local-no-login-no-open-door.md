# smidja · 2026-11-14 — the smithy drops its hosted-era login and pins its door to loopback

**Component:** smidja · **Branch:** `eindri/smidja-header-chat` (plan 275, item 30)
**Files:** `apps/smidja-factory/apps/visualizer/server/index.ts`, `src/App.vue` (+ tracked `dist/`)

## Why

The Allfather, plan 275 §05:00: *"this feature of opening online must go away with the logins we
have. we are not hosting the 3 apps online.. they are local."* The §05:20 audit listed Smíðja's
share of what was built for hosting behind a login.

## What was there, and what went

| Piece | Where | Now |
|---|---|---|
| `/api/auth` — forwarded the browser cookie to Hlidskjalf's gate for a verdict | `server/index.ts:172-190` | **removed**; the route answers 404 |
| the header's account bits — `ᛉ <login>` when signed in, "Sign in" when not, and the `auth`/`gateUrl` state behind them | `src/App.vue:28-40, 118-119` | **removed**; there is no sign-in in the header |
| `HOST` read from the environment for the listen address | `server/index.ts:24` (used at `:158`) | **pinned to `127.0.0.1`**, on purpose, with the reason in the code |

**About `server/settings.ts`.** The audit named "auth in its server settings". Measured: that file
holds no auth at all — it is the WayOfTeams **MCP token** (`WAYOFTEAMS_MCP_TOKEN`, `WOTEAMS_*`)
that the chat's pi process needs to load the teams MCP surface. That is a credential for a local
tool, not a login gate (the same shape as Sessrúmnir's model-provider keys, which item 30 keeps),
so it stays. Likewise `SessionTrace.vue` carries no account bits — measured, not assumed.

## Proof

```
$ HOST=0.0.0.0 PORT=8539 bun run server/index.ts
$ ss -ltn | grep 8539
LISTEN 0 512 127.0.0.1:8539 …     ← a stray HOST can no longer widen the door
$ curl the machine's own network address on 8539
curl: (7) Failed to connect             ← refused; the door is not on the network
$ curl http://127.0.0.1:8537/api/auth   (loopback, not a network address)
404                                      ← the login route is gone
```

In the real window (private Electron, DevTools 9444): `document.querySelectorAll('.topbar a')`
holds the six nav doors and no "Sign in"/`ᛉ` link; the theme toggle and window controls stay.
`vue-tsc --noEmit` 0, `vite build` 0.

## Not done, named

The **Hlidskjalf** half of item 30 — the gate's own login, the accounts store, the invite codes,
the lane chooser and the rails/tunnel guard — is errand `hall-follow` part (f). This note closes
only Smíðja's rows. The operator's contract text about the in-app login belongs to that same
change, since it describes Hlidskjalf's gate, not this app.

## CHANGE LOG

- 2026-11-14 — Smíðja: `/api/auth` and the header's account bits removed; `HOST` pinned to
  loopback; `settings.ts` (the MCP token) deliberately kept, with the reason recorded.

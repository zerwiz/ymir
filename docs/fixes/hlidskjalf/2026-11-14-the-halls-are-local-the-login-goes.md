# hlidskjalf · 2026-11-14 — the hosted-era login goes: the halls are local

**Component:** hlidskjalf · **Branch:** `eindri/hall-follow` (plan 275, item 30 · plans 277 and 279)
**Files:** `apps/hlidskjalf/server/index.ts`, `server/accounts.ts` (deleted),
`src/components/LoginModal.tsx` (deleted), `src/components/Halls.tsx` (deleted),
`src/app/App.tsx`, `src/components/AccountMenu.tsx`, `src/services/auth.ts`,
`src/services/api.ts`, `src/state/store.ts`, `src/gates/Profile.tsx`, `electron/main.cjs`,
`bin/engine/ymir-invite.sh` (deleted), `bin/engine/ymir-setup-auth.sh` (deleted),
`bin/engine/ymir-install.sh`, `bin/engine/ymir.js`, `bin/bridge/ymir-plan.sh`,
`bin/forge/gjallarhorn-tunnel.sh`, `AGENTS.md`, `.env.example`, `.env.sample`, `README.md`,
`STRUCTURE.md`, `docs/features/hlidskjalf-the-control-plane.md`,
`.agents/skills/galdr-ymirsystem/assets/{hlidskjalf-ui,installation}.md`

## Why

At the Allfather's word, plan 275 §2026-11-14 05:00: *"this feature of opening online must go
away with the logins we have. we are not hosting the 3 apps online, they are local. [a
collaborator's security review] found that we were opening ports out. we have a plan for this. this
was a feature from very long time ago."*

The 05:00 and 05:20 audits measured what remained of the hosted era: the gate's own login
(`HLIDSKJALF_AUTH`), an accounts store with invite codes, a GitHub OAuth door, a set of public
hostnames the gate fronted apps behind (`YMIR_PRIMARY_HOST`, `SMIDJA_HOST`, `ODRERIR_HOST`),
the "Take your seat — three halls share one login" chooser, and a tunnel script documented as
exposing the gate on `:3889`. The halls already listened on loopback only; the login was the
last claim that they did not have to.

## What changed

**The gate asks nothing.** `/api/login`, `/api/register`, `/api/invites`, `/api/logout`,
`/api/auth/github` and its callback are gone, with the signed-cookie session machinery, the
accounts store (`server/accounts.ts`), `GATE_AUTH`, `APP_HOSTS`/`PRIMARY_HOST` and the
reverse-proxy that fronted Smíðja and Óðrerir behind the login. `/api/session` answers
`{login: 'operator', surface: 'local'}` — a name, never a credential. The two doors that still
judge the request (`/api/rodd`, `/api/skirnir/voice/`) keep their loopback + same-origin ward
verbatim; only their session dependence is gone (the local seat is the operator).

**Loopback is enforced, not assumed.** The gate refuses to bind a non-loopback `HLIDSKJALF_HOST`
unless `YMIR_ALLOW_WIDE_BIND=1`, printing why and pointing at Gimlé (plan 284).

**No tunnel to a hall.** `bin/forge/gjallarhorn-tunnel.sh start` reads the cloudflared config's
ingress and **refuses** (exit 3) a config whose `service:` points at a hall port — 3888, 3889,
4322, 4602, 4603, 8437, 8787, 3891 — with the reason and the help line. Its header no longer
claims to expose Hlidskjalf.

**The face.** `LoginModal` and `Halls` (the chooser and its `raise`) are deleted; `App` boots
straight into the Shell and establishes the seat from `/api/session`; `AccountMenu` says
`local seat` and offers no Sign out; `signOut` is gone from the store; `Profile`'s tenant rows
name the **workspace and its shelf** (`svartalfaheim/<realm>`) and no longer print a grant
(`Owner`), because there is nobody to grant to. The Electron shell loses its `/api/logout`
sign-out and its menu item.

**The distribution.** `bin/engine/ymir-invite.sh` and `bin/engine/ymir-setup-auth.sh` are
deleted; the installer's `invite` and `auth` steps remain in the report and answer with a clean
skip naming plan 275 item 30 and Gimlé (plan 284); `ymir.js` loses the `heimdall` and `invite`
verbs; `bin/bridge/ymir-plan.sh` emits the same skip instead of a CONSENT.

**The record.** `AGENTS.md` carries a dated entry that supersedes its *"Access: the gate shows an
in-app login … invite code … GitHub sign-in"* paragraph, and that paragraph now says what is
true. The feature page and both galdr assets are corrected in the same change.

## Which plan items this closes

- **Plan 277** — §1's **Local** reach row for the halls: loopback only, *no credential needed*.
  The three tables in 277 stand; slices 2–4 are untouched.
- **Plan 279** — §1 row 2's residue on the halls' side: the ports were already closed (#705,
  #712); what remained was the login that pretended to guard them. The collaborator's other
  eleven findings are untouched and stay as plan 279 records them.

## How it was proved

```
grep -rn "HLIDSKJALF_AUTH|/api/login|LoginModal|HallsChooser|accounts.ts" apps/ bin/  → nothing
gate from this worktree: GET /api/session → {"login":"operator","surface":"local"}
probe /api/login (POST)  → {"error":"no route /api/login"} 404
HLIDSKJALF_HOST=0.0.0.0 bun run server/index.ts → refuses, exit 2
YMIR_TUNNEL_CONFIG=<config pointing at :3889> gjallarhorn-tunnel.sh start → refused, exit 3
YMIR_TUNNEL_CONFIG=<config pointing at :8761> gjallarhorn-tunnel.sh start → allowed
npx tsc --noEmit (apps/hlidskjalf) → exit 0;  npm run build → clean
bash -n on every script touched; node --check bin/engine/ymir.js electron/main.cjs
```

## Not done, named

- **Smíðja's own auth rows** (`visualizer/server/settings.ts`, `HOST` from the environment) are
  errand `smidja-header-chat`'s per the plan's 05:20 table, not this one.
- **`/api/desktop`** stays: it is the launcher the key bindings and shell scripts already use,
  and it grants nothing.
- **`system.hallUrl`** in Sessrúmnir's preload is left (a local URL probe, not a button); the
  status-bar button that used it is removed under item 33.
- **The vault key `hodd/state/gate-session.key`** is no longer read or written; it is left on
  disk rather than deleted, because a key removed by an agent is a decision the Allfather has
  not made.

## CHANGE LOG

- 2026-11-14 — login, invites, the GitHub door, the app hosts, the chooser and the tunnel-to-a-hall
  removed; the gate binds loopback and says so.

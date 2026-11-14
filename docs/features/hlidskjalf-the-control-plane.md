# Hlidskjalf — the control plane

## What it is

**Hlidskjalf** is Ymir's dashboard — the Allfather's high seat. It is where you *see* the
system: the workspaces, the runs, the record, the fleet — over one page instead of a
dozen terminals. The **gate API** behind it reads the runtime, so the portal is the single
way in — and since 2026-11-14 it asks for no credential at all (plan 275 item 30): the
halls are local, loopback only, and the desktop session is the authority.

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
| Gate API (`/api/*`) | `http://127.0.0.1:3889` |

Open **http://127.0.0.1:3888** in a browser. There is **no login**: the halls are
local, the desktop session is the authority, and the gate answers with your own
name and nothing to sign in with (plan 275 item 30).

### Let someone else in — not through a hall

Nothing here lets a second person in, and nothing should: the three apps are not
hosted. Hosted, shared surfaces are **Gimlé**'s (plan 284). The old invite codes,
the accounts store and the GitHub door were for a hosted instance and were removed
on 2026-11-14.

### Reach it from another machine — no

A hall never leaves this machine. `bin/forge/gjallarhorn-tunnel.sh` now **refuses**
to start a tunnel whose config points at a hall port (3888, 3889, 4602, 4603,
4322, 8437, 8787). A tunnel fronts a public surface (Gimlé, a video forge, a
notice door), never Hlidskjalf, Smíðja or Óðrerir.

### The desktop shell

```bash
scripts/electron.sh start                 # an Electron window over Hlidskjalf
scripts/electron.sh start --view smidja   # …or the Smiðja visualizer
scripts/electron.sh stop | status
```

## Notes and limits

- **Local, full stop.** The SPA (`:3888`) and the gate (`:3889`) bind loopback, and
  the gate refuses a wider bind unless `YMIR_ALLOW_WIDE_BIND=1`.
- **No account, no grant.** There is nothing to sign in with and nothing to grant;
  the realm list in Profile shows the workspaces (the realm folders), not roles.
- **One control plane.** Other surfaces (Óðrerir, Smiðja) are their own apps, but
  Hlidskjalf is the seat you actually look at.
- Ports are configuration (Rule 07): `HLIDSKJALF_PORT`, `HLIDSKJALF_API_PORT`.

## If it does not work

| What you see | What to do |
|---|---|
| Nothing on `:3888` | `scripts/start.sh` and watch its output; check `scripts/start.sh --help`. |
| Another machine cannot reach it | That is the design: a hall is loopback only. A shared surface is Gimlé (plan 284). |
| `refusing to listen on …` in the gate's log | Something set `HLIDSKJALF_HOST` to a non-loopback address; unset it (or `YMIR_ALLOW_WIDE_BIND=1` for a deliberate test). |

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-14** — the halls carry no login (plan 275 item 30): the in-app login, the invite codes, the GitHub door and the tunnel-to-a-hall are removed; the page now says what is true.

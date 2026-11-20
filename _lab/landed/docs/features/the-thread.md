# Þráðr — a real shell in the high seat

> **Status:** shipped 2026-10-20 as T0+T1+T2 of plan 93. A real pty through the gate, so
> `herdr` opens *inside* Hlidskjalf with its panes and agents.

## What it is

A terminal gate in Hlidskjalf. Not a picture of a terminal: a **real pty**, running your own
login shell, in the app — so `herdr`, `vim`, `htop` and anything else with a TTY behaves
exactly as it does in a terminal window.

Two quick actions sit above it:

| button | what it does |
|---|---|
| **open herdr** | opens a shell and types `herdr` — the real TUI, its panes and its agents |
| **who stands** | `herdr agent list`, the roster, before you attach |
| **plain shell** | just your `$SHELL`, with no command typed |

The status strip names the seat's own truth before you press anything: enabled or disabled,
**loopback only** or remote-allowed, which shell, which directory, how many shells are open
against the cap, and when an idle shell is closed.

## What you need

- The app built and served (`scripts/start.sh` raises Hlidskjalf on `:3888`; the gate API on
  `:3889` is what opens the shell).
- `node` on `PATH` — the shell is born in a small **broker** process (see Limits).
- For herdr: `herdr` on `PATH` (it is, on any seat that runs Ymir's terminal backend).

## The commands

In the app: open the **Þráðr** gate. Locally, without the UI:

```sh
bin/seat/verknadr.sh status      # not part of this feature; kept for reference only
curl -s -b cookie.txt http://127.0.0.1:3889/api/terminal/status
```

The status route answers without opening anything:

```json
{"enabled":true,"remoteAllowed":false,"shell":"/usr/bin/bash","cwd":"/…/ymir",
 "open":0,"maxPerUser":4,"idleTimeoutMs":1800000}
```

## Limits — read these

- **A terminal is remote code execution by design.** So: no shell without a live gate
  session; the WebSocket upgrade checks the same `ymir_session` cookie the SPA uses (never a
  token in the URL); the `Origin` must equal the gate's own host; and a **non-loopback peer is
  refused** unless the operator sets `YMIR_TERMINAL_ALLOW_REMOTE=1`. Over the Cloudflare
  tunnel, that flag is the difference between a local tool and a remote shell — decide it
  deliberately.
- **The socket owns the shell.** Close the tab and the pty is killed; the gate closing kills
  every shell it owns. There is no orphan.
- **Four shells per user, 30 minutes idle.** Both are enforced server-side
  (`YMIR_TERMINAL_MAX`, `YMIR_TERMINAL_IDLE_MS`).
- **Every open and close is a rune** in `hodd/memory/runes_audit.md`.
- **Turn it off entirely** with `YMIR_TERMINAL=0` (the gate then answers `403`, and the gate
  itself says why instead of showing an empty rectangle).
- **Why a broker:** `node-pty` does not survive inside **Bun** — a pty spawned in the gate
  prints its prompt and dies with SIGHUP within a tick. The shell is therefore spawned by a
  Node broker over a **Unix socket** in your runtime directory (`0600`), which binds no port.
  If `node` is missing, the terminal reports it; it never pretends.

## If it does not work

| symptom | cause | remedy |
|---|---|---|
| gate shows `refused: not signed in` | the session expired, or the gate restarted (sessions are in memory) | sign in again |
| `refused: a terminal is loopback-only on this seat` | you reached the gate from another host | use the desktop app, or set `YMIR_TERMINAL_ALLOW_REMOTE=1` deliberately |
| `the pty broker did not answer` | `node` is not on the gate's PATH, or the socket dir is not writable | run the gate with a PATH that has `node`; check `$XDG_RUNTIME_DIR` |
| `terminal limit reached (4)` | four shells open | close one; they are listed in the status strip |
| a shell opens and dies at once | `node-pty` was never compiled on this machine | `cd apps/hlidskjalf/node_modules/node-pty && npx node-gyp rebuild` |

# Þráðr: a real terminal in Hlidskjalf — and the three faults found building it

**Date:** 2026-10-20 · **Component:** `hlidskjalf` · **Plan:** 93 · **Rules:** 07 (nothing hardcoded), 24 (the ward)

## What landed

A **Þráðr** gate in Hlidskjalf: a real pty, through the gate API, so `herdr` opens inside the
app with its panes and agents.

| piece | what it does |
|---|---|
| `src/components/Terminal.tsx` | xterm.js + fit + web-links, **themed from the app's own CSS variables**, one WebSocket, resize observed, a closed tab closes the shell |
| `src/gates/Thradr.tsx` | the gate: status strip, **open herdr**, **who stands** (`herdr agent list`), plain shell |
| `server/pty.ts` | the laws: opt-out, per-owner cap (4), idle timeout (30 min), one pty per id, socket owns the shell, every open/close a **rune** |
| `server/pty-broker.mjs` | the shell is spawned by **Node** over a Unix socket (see fault 1) |
| `server/index.ts` | the door: `/api/terminal` upgrade + `/api/terminal/status`; cookie session, `Origin` check, **loopback by default** (`YMIR_TERMINAL_ALLOW_REMOTE=1` to widen) |

## The three faults, each measured

**1 · `node-pty` does not survive under Bun — the reason there is a broker.**
A pty spawned in the gate process printed its prompt and then died with **SIGHUP** within a
tick; the identical call under **Node** stayed alive indefinitely. Bun closes the descriptor
node-pty handed it. So the shell is born in `pty-broker.mjs` (Node, Unix socket in
`$XDG_RUNTIME_DIR`, mode `0600`, **no port**), and the gate is its client. The alternative —
turning the whole gate into a Node server — would have been a rewrite for one feature.

**2 · A spawned broker did not inherit the socket path.**
`spawn(node, [script], { env: { …process.env, YMIR_THRADR_SOCKET: path } })` produced a broker
listening on the **default** path while the gate knocked on another one, and the gate retried
into a socket nobody was listening on. The path is now **argv[2]** — said, not hoped for.

**3 · `config/` is a symlink.** `git add config/logretta-stack.example.yaml` was refused
("beyond a symbolic link"); the real shelf is `.agents/config/`. A note for the next hand.

## Verified

```
bun test server/pty.test.ts   · 8/8
  terminals are opt-out · a disabled seat refuses · remote is refused without the word
  the shell is the operator's own · cap 4 per owner · same id replaces · close is idempotent
  a REAL shell is born and carries output both ways
npx tsc --noEmit · clean          npx vite build · ✓ built
```

**End to end, against a live gate on `:3899`:**

```
GET  /api/terminal/status (no cookie)        → 401 {"error":"unauthorized"}
GET  /api/terminal/status (cookie)           → enabled, remoteAllowed:false, shell bash, cap 4, idle 30 min
WS   /api/terminal + cookie + Origin         → ready → `echo THRADR-OK` → THRADR-OK, real prompt
runes                                         → "terminal open: … (op) shell=/usr/bin/bash pid=…"
                                              → "terminal close: … reason=socket-closed"
```

The last line is the law that matters: the **socket closed, and the shell died with it**.

## Not done (plan 93 T3/T4 remainder)

- The herdr **panel** (list + one-click attach) ships as the two quick actions; a dedicated
  pane-list view is still to come.
- The `security-audit` check ("is a pty listening, and is it authenticated?") is not written
  yet — the door is loopback-only and cookie-gated today, but the ward should say so every day.
- The tunnel decision is the Allfather's: `YMIR_TERMINAL_ALLOW_REMOTE=1` is the one flag
  between a local tool and a remote shell.

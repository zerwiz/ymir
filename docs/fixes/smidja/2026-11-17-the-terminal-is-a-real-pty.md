## smidja · unversioned · 2026-11-17 — the terminal is a real PTY, attached to the agent's own session

### Why

The Smíðja's terminal view was a **sample**: `herdr agent read`, polled twice a second, printed as
text. You could watch an agent, and you could not work with it. The Allfather asked for the real
thing — *a live PTY per worker, not a log tail and not a picture of one* — so the operator can see
the run and type into it.

### The road taken, and why

| candidate | verdict |
|---|---|
| **xterm.js + node-pty** (MIT, the pair VS Code's and Tabby's terminals are built on) | **taken** — one real pseudo-terminal per connection, signals and job control working |
| ttyd (MIT, single C binary) | not taken — not installed on this box, and it gives each browser its own process; the same job is done here without a second server |
| WeTTY | not taken — it wants sshd and an account, and has no read-only mode |

**node-pty does not work under Bun.** Measured on this box (heimdall, 2026-11-17): the same
`pty.spawn` call returns a real `/dev/pts/30` and its output under **node**, and under **bun** it
exits 0 with **no output at all** — a silent, total failure. So the visualizer (Bun) spawns
`server/terminal-pty.mjs` with `node`, and pipes bytes; the PTY host is one small file, not a second
server and not a second port.

### The mends

| mend | where |
|---|---|
| a real PTY per connection, holding `herdr agent attach <pane>` — **the agent's own session**, so what you see is the run and what you type reaches it | `server/terminal-pty.mjs` (new) |
| `ws://127.0.0.1:<port>/api/terminal?pane=&cols=&rows=` — one socket, one PTY, keystrokes in, bytes out | `server/index.ts` (websocket) |
| **loopback twice over**: the server binds `127.0.0.1`, and the route refuses any peer that is not loopback even behind a proxy | `server/index.ts` (`requestIP`) |
| a dead PTY **says dead**, with its exit code — never a frozen screen | `server/terminal-pty.mjs` (`exit` frame), `LiveTerminal.vue` |
| the pane survives a **reload**: the open pane and the read/terminal choice are remembered, so a reload attaches again to the same session | `PaneDrawer.vue` (`localStorage`), `LiveTerminal.vue` |
| `read` · `terminal` · `raise` · `close` — the drawer's four controls, in the board | `PaneDrawer.vue` |
| a resize travels as a private sequence (`ESC ]999;cols;rows BEL`) and is stripped before the agent sees it, so a resize never arrives as typing | `server/terminal-pty.mjs` |
| herdr allows **one attached client per terminal**; a viewer that died without detaching leaves the slot claimed, so a refused attach is answered by `--takeover`, announced to the board | `server/terminal-pty.mjs` |

### Proof

```bash
# a real seat to attach to
bin/seat/herdr-run.sh eindri term-proof2 --kind pi --model opencode-go/deepseek-v4.1-flash \
  --seat-cwd /tmp/smidja-proof -- "You are the second test seat for the live terminal."
→ "pane","term-proof2","sindri","pi","wN:t1","wN:pJ","idle"
```

- **a live terminal on the agent's session**: the drawer in `terminal` mode rendered the agent's own
  TUI — its seat-law text, its reply `[from agent Hœnir] Seat two is live…`, and its prompt.
- **a keystroke landing in the agent**: typing `KEYSTROKE-PROOF-42` into the browser's xterm and then
  asking the agent's own pane:
  `herdr agent read wN:pJ --source visible` → `KEYSTROKE-PROOF-42`.
- **a reload re-attaching to the same PTY**: after `Page.reload`, the drawer reopened itself in
  `terminal` mode on `wN:pJ`, the agent's line still held `KEYSTROKE-PROOF-42` — the same session,
  not a new one.
- **loopback**: `ss -tlnp | grep 8447` → `127.0.0.1:8447`; a pane id with `../` → `400`; a request
  without the upgrade → `400`; a loopback handshake → `101 Switching Protocols`.

### What this is not

- It is **not** a shell: the only command the PTY ever runs is `herdr agent attach <pane>`, so the
  socket cannot be used to start anything else.
- It is **not** public: loopback bind plus a loopback peer check. A terminal server on a public port
  is a shell on the machine, and this house does not do that.

#!/usr/bin/env node
/**
 * terminal-pty.mjs — ONE real pseudo-terminal, attached to ONE agent session.
 *
 * This is the server half of the Smíðja's live terminal: a genuine PTY (not a
 * log tail, not a picture of one), holding `herdr agent attach <pane>` — the
 * SAME session the agent is already running in, so the operator sees the live
 * run and can type into it.
 *
 * WHY NODE AND NOT BUN. `node-pty` is a native addon; measured on this box
 * (heimdall, 2026-11-17) the same call spawns a real `/dev/pts/N` under Node and
 * exits 0 with NO output at all under Bun — a silent, total failure. So the
 * visualizer (Bun) spawns THIS file with `node` and pipes bytes, instead of
 * pretending the PTY worked.
 *
 * The contract with the server is bytes, both ways:
 *   stdin   ← keystrokes from the websocket, written straight into the PTY
 *   stdout  → everything the PTY printed, sent straight to the websocket
 *   stderr  → one JSON line per control event: {"type":"ready"|"exit", ...}
 *
 * A resize travels as a private sequence on stdin — `ESC ] 9 9 9 ; <cols> ; <rows> BEL`
 * — which is stripped here and never reaches the agent's terminal, so a keystroke
 * is never eaten and a resize never arrives as typing.
 *
 * A dead PTY is ANNOUNCED (`exit`), never left as a frozen screen that looks
 * alive — the 27-shells lesson, one layer down (plan 001).
 *
 * Usage: node terminal-pty.mjs <pane-id> [cols] [rows]
 */
import { spawn } from "node-pty";

const pane = process.argv[2] ?? "";
const cols = Number(process.argv[3] ?? 120) || 120;
const rows = Number(process.argv[4] ?? 32) || 32;

if (!/^[\w:.@-]+$/.test(pane)) {
  process.stderr.write(JSON.stringify({ type: "exit", code: 2, why: "not a pane id" }) + "\n");
  process.exit(2);
}

const say = (event) => process.stderr.write(JSON.stringify(event) + "\n");

/**
 * `herdr agent attach` is the client that joins the agent's OWN terminal: the
 * agent keeps running whether or not anyone is watching, so a reload attaches
 * again to the same session instead of starting a new one.
 *
 * ONE CLIENT PER TERMINAL, and that is herdr's rule, not ours: a viewer that dies
 * without detaching (a closed tab, a killed process) leaves the slot claimed, and
 * the next attach is refused with `terminal … already has an attached client;
 * retry with --takeover` (measured 2026-11-17). So a plain attach is tried first
 * — never stealing from a live viewer — and the specific refusal is answered by
 * taking the slot over, ANNOUNCED to the board so the operator knows this view
 * now owns the terminal.
 */
const attachArgs = (takeover) => (takeover ? ["agent", "attach", pane, "--takeover"] : ["agent", "attach", pane]);

let child;
let takenOver = false;
let seen = "";

function start(takeover) {
  child = spawn("herdr", attachArgs(takeover), {
    name: "xterm-256color",
    cols,
    rows,
    cwd: process.env.HOME ?? "/",
    env: { ...process.env, TERM: "xterm-256color" },
  });

  say({ type: "ready", pane, pid: child.pid, cols, rows, takeover });

  child.onData((data) => {
    if (seen.length < 4000) seen += data;
    process.stdout.write(data);
  });

  child.onExit(({ exitCode, signal }) => {
    const refused = seen.includes("already has an attached client");
    if (refused && !takenOver) {
      takenOver = true;
      seen = "";
      say({ type: "takeover", pane });
      start(true);
      return;
    }
    say({ type: "exit", code: exitCode, signal: signal ?? null });
    process.exit(0);
  });
}

start(false);

// ── stdin: keystrokes through, resize sequences out ─────────────────────────
const RESIZE = /^\x1b\]999;(\d+);(\d+)\x07/;
let held = "";

function pump() {
  for (;;) {
    const at = held.indexOf("\x1b]999;");
    if (at === -1) {
      // No control sequence at all — but keep a possible partial prefix back.
      const keep = Math.max(0, Math.min(held.length, 16));
      const tail = held.slice(held.length - keep);
      const cut = tail.lastIndexOf("\x1b");
      if (cut >= 0) {
        const body = held.slice(0, held.length - keep + cut);
        if (body) child.write(body);
        held = held.slice(held.length - keep + cut);
      } else {
        if (held) child.write(held);
        held = "";
      }
      return;
    }
    if (at > 0) {
      child.write(held.slice(0, at));
      held = held.slice(at);
      continue;
    }
    const match = RESIZE.exec(held);
    if (!match) {
      if (held.length > 32) {
        // Not a resize after all — flush rather than hold forever.
        child.write(held.slice(0, 1));
        held = held.slice(1);
        continue;
      }
      return; // wait for the rest of the sequence
    }
    held = held.slice(match[0].length);
    try {
      child.resize(Number(match[1]), Number(match[2]));
    } catch {
      /* a dead PTY; onExit announces it */
    }
  }
}

process.stdin.on("data", (chunk) => {
  held += chunk.toString("utf8");
  try {
    pump();
  } catch {
    /* the PTY is gone */
  }
});

process.stdin.on("end", () => {
  try {
    child.kill();
  } catch {
    /* already dead */
  }
});

process.on("SIGTERM", () => {
  try {
    child?.kill();
  } catch {
    /* ignore */
  }
  process.exit(0);
});

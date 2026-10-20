#!/usr/bin/env node
/**
 * pty-broker — the one place a real shell is born for Þráðr (plan 93).
 *
 * WHY A SEPARATE PROCESS, MEASURED 2026-10-20: `node-pty` does not survive under **Bun**.
 * A pty spawned in the gate process emits its prompt and then dies with SIGHUP within a
 * tick — Bun closes the descriptor node-pty handed it. The same call under **Node** stays
 * alive indefinitely. So the shell is spawned by Node, and the Bun gate talks to it over a
 * LOCAL Unix socket.
 *
 * That is not a second door: it binds no port, opens no TCP, and speaks only to a socket
 * in the operator's own runtime directory (0700 / 0600), exactly as herdr's own server does.
 * The gate stays the only network surface, and it stays the only place that decides WHO
 * may open a shell.
 *
 * Protocol — newline-delimited JSON, one object per line.
 *   → {"op":"open","id":"…","cwd":"…","cols":120,"rows":32}
 *   → {"op":"i","id":"…","d":"ls\r"}
 *   → {"op":"r","id":"…","cols":140,"rows":40}
 *   → {"op":"close","id":"…"}
 *   ← {"ev":"ready","id":"…","shell":"…","pid":123,"cwd":"…"}
 *   ← {"ev":"o","id":"…","d":"…"}          (terminal output)
 *   ← {"ev":"exit","id":"…","code":0}
 *   ← {"ev":"error","id":"…","m":"…"}
 */
import { createServer } from "node:net";
import { existsSync, unlinkSync, chmodSync } from "node:fs";
import { homedir, userInfo } from "node:os";
import { join } from "node:path";
import pty from "node-pty";

const RUNTIME = process.env.XDG_RUNTIME_DIR;
const UID = typeof process.getuid === "function" ? process.getuid() : 0;
// The path may arrive as argv[2] — the gate passes it explicitly, because a spawned child
// did not reliably inherit the env var (measured 2026-10-20: it bound the default path while
// the gate knocked on another socket).
const SOCKET = process.argv[2]
  ? process.argv[2]
  : process.env.YMIR_THRADR_SOCKET
  ? process.env.YMIR_THRADR_SOCKET
  : RUNTIME
    ? join(RUNTIME, "ymir-thradr.sock")
    : join("/tmp", `ymir-thradr-${UID}.sock`);

const shellFor = () => {
  const s = process.env.SHELL?.trim();
  if (s && existsSync(s)) return s;
  return existsSync("/bin/bash") ? "/bin/bash" : "/bin/sh";
};

/** id -> { pty, server } */
const sessions = new Map();

function send(conn, obj) {
  try {
    conn.write(JSON.stringify(obj) + "\n");
  } catch {
    /* the gate went away; the connection's close handler reaps its ptys */
  }
}

function open(conn, msg) {
  const id = String(msg.id ?? "");
  if (!id) return send(conn, { ev: "error", id, m: "a terminal needs an id" });
  if (sessions.has(id)) {
    try {
      sessions.get(id).pty.kill();
    } catch {
      /* already gone */
    }
    sessions.delete(id);
  }
  const shell = shellFor();
  const cwd = msg.cwd && existsSync(msg.cwd) ? msg.cwd : homedir();
  let proc;
  try {
    proc = pty.spawn(shell, [], {
      name: "xterm-256color",
      cols: Number(msg.cols) > 0 ? Math.floor(Number(msg.cols)) : 120,
      rows: Number(msg.rows) > 0 ? Math.floor(Number(msg.rows)) : 32,
      cwd,
      env: { ...process.env, TERM: "xterm-256color" },
      encoding: "utf8",
    });
  } catch (err) {
    return send(conn, { ev: "error", id, m: `could not spawn ${shell}: ${err?.message ?? err}` });
  }

  const entry = { pty: proc, conn };
  sessions.set(id, entry);
  send(conn, { ev: "ready", id, shell, pid: proc.pid, cwd });

  proc.onData((d) => send(conn, { ev: "o", id, d }));
  proc.onExit(({ exitCode }) => {
    if (sessions.get(id) === entry) sessions.delete(id);
    send(conn, { ev: "exit", id, code: exitCode });
  });
}

const server = createServer((conn) => {
  conn.setEncoding("utf8");
  let buf = "";
  conn.on("data", (chunk) => {
    buf += chunk;
    let nl;
    while ((nl = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, nl);
      buf = buf.slice(nl + 1);
      if (!line.trim()) continue;
      let msg;
      try {
        msg = JSON.parse(line);
      } catch {
        continue;
      }
      const id = String(msg.id ?? "");
      const entry = sessions.get(id);
      if (msg.op === "open") open(conn, msg);
      else if (msg.op === "i" && entry) entry.pty.write(String(msg.d ?? ""));
      else if (msg.op === "r" && entry) {
        const cols = Math.floor(Number(msg.cols));
        const rows = Math.floor(Number(msg.rows));
        if (cols > 1 && rows > 1 && cols < 1000 && rows < 1000) {
          try {
            entry.pty.resize(cols, rows);
          } catch {
            /* a resize on a dying pty is not an error worth surfacing */
          }
        }
      } else if (msg.op === "close" && entry) {
        sessions.delete(id);
        try {
          entry.pty.kill();
        } catch {
          /* already gone */
        }
      }
    }
  });
  // The gate closing its side owns the shells it opened on that connection.
  conn.on("close", () => {
    for (const [id, entry] of [...sessions.entries()]) {
      if (entry.conn !== conn) continue;
      sessions.delete(id);
      try {
        entry.pty.kill();
      } catch {
        /* already gone */
      }
    }
  });
  conn.on("error", () => {});
});

function shutdown() {
  for (const [, entry] of [...sessions.entries()]) {
    try {
      entry.pty.kill();
    } catch {
      /* already gone */
    }
  }
  sessions.clear();
  try {
    server.close();
    unlinkSync(SOCKET);
  } catch {
    /* nothing to clean */
  }
  process.exit(0);
}

try {
  if (existsSync(SOCKET)) unlinkSync(SOCKET);
  server.listen(SOCKET, () => {
    try {
      chmodSync(SOCKET, 0o600);
    } catch {
      /* best effort: the socket lives in a 0700 dir on Linux */
    }
    console.log(`[thradr-broker] listening ${SOCKET} (uid ${userInfo().uid})`);
  });
} catch (err) {
  console.error(`[thradr-broker] could not listen on ${SOCKET}: ${err?.message ?? err}`);
  process.exit(1);
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

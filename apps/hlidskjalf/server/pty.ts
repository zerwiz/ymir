/**
 * pty — Þráðr's engine: a REAL shell per terminal, and the laws that bound it.
 *
 * Plan 93. A terminal in the high seat is remote code execution by design, so this file is
 * written as a ward first and a feature second:
 *
 *   · the shell is the operator's own ($SHELL), never a hardcoded bash (Rule 07)
 *   · ONE pty per session; a new one for the same id replaces the old
 *   · a per-owner CAP and an IDLE TIMEOUT, enforced here — a shell that outlives its tab is
 *     a shell running unattended
 *   · every open and close is a RUNE (the append-only ledger)
 *   · closing the socket kills the pty: the socket owns the shell, always
 *
 * WHY A BROKER (measured 2026-10-20): `node-pty` does not survive under Bun — a pty spawned
 * in this process prints its prompt and dies with SIGHUP within a tick, because Bun closes
 * the descriptor node-pty handed it. The same call under Node stays alive. So the shell is
 * born in `pty-broker.mjs` (Node, a local Unix socket, no port), and this file is its client.
 * The gate remains the only network surface and the only place that decides who may enter.
 */
import { spawn, type ChildProcess } from "node:child_process";
import { createConnection, type Socket } from "node:net";
import { appendFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const MAX_SESSIONS_PER_USER = Number(process.env.YMIR_TERMINAL_MAX ?? 4);
export const IDLE_TIMEOUT_MS = Number(process.env.YMIR_TERMINAL_IDLE_MS ?? 30 * 60 * 1000);
export const DEFAULT_COLS = 120;
export const DEFAULT_ROWS = 32;

/** Every terminal is opt-out, but a seat may turn them off outright. */
export function terminalsEnabled(): boolean {
  return process.env.YMIR_TERMINAL !== "0";
}

/** Whether a NON-loopback peer may open a shell. Off unless the Allfather says otherwise. */
export function terminalsAllowRemote(): boolean {
  return process.env.YMIR_TERMINAL_ALLOW_REMOTE === "1";
}

export function shellFor(): string {
  const s = process.env.SHELL?.trim();
  if (s && existsSync(s)) return s;
  return existsSync("/bin/bash") ? "/bin/bash" : "/bin/sh";
}

/** Read the repo root a terminal should open in, if the app knows one. */
export function defaultCwd(): string {
  const root = process.env.YMIR_ROOT?.trim();
  if (root && existsSync(join(root, ".pi"))) return root;
  return homedir();
}

export function socketPath(): string {
  if (process.env.YMIR_THRADR_SOCKET) return process.env.YMIR_THRADR_SOCKET;
  const runtime = process.env.XDG_RUNTIME_DIR;
  const uid = typeof process.getuid === "function" ? process.getuid() : 0;
  return runtime ? join(runtime, "ymir-thradr.sock") : join("/tmp", `ymir-thradr-${uid}.sock`);
}

export interface TerminalHandlers {
  onData: (chunk: string) => void;
  onExit: (info: { exitCode: number }) => void;
}

export interface OpenedTerminal {
  id: string;
  pid: number;
  shell: string;
  cwd: string;
}

interface Session {
  id: string;
  owner: string;
  createdAt: number;
  lastActivity: number;
  timer: ReturnType<typeof setInterval>;
  handlers: TerminalHandlers;
}

/** One broker connection, lazily spawned, shared by every terminal on this gate. */
class Broker {
  private conn: Socket | null = null;
  private launching: Promise<void> | null = null;
  private buffer = "";
  private next: ((msg: any) => void) | null = null;

  /** Resolves when the socket is connected (spawning the broker if it is not there). */
  async ready(): Promise<void> {
    if (this.conn && !this.conn.destroyed) return;
    if (this.launching) return this.launching;
    this.launching = (async () => {
      const path = socketPath();
      if (!existsSync(path)) this.spawnBroker();
      await this.connect(path);
      this.launching = null;
    })();
    return this.launching;
  }

  private spawnBroker(): void {
    const here = import.meta.dir;
    const script = join(here, "pty-broker.mjs");
    if (!existsSync(script)) throw new Error(`no pty broker at ${script}`);
    const node = process.env.YMIR_NODE_BIN?.trim() || "node";
    // The socket path is passed EXPLICITLY: measured 2026-10-20, a broker spawned from the
    // gate did not inherit YMIR_THRADR_SOCKET and bound the default path instead, so the
    // gate retried against a socket nobody was listening on. Say it, do not hope for it.
    const path = socketPath();
    let child: ChildProcess;
    try {
      child = spawn(node, [script, path], {
        detached: true,
        stdio: "ignore",
        env: { ...process.env },
      });
    } catch (err) {
      throw new Error(`the pty broker could not start (${node}): ${(err as Error).message}`);
    }
    child.on("error", () => {
      /* reported by the connect failure below */
    });
    child.unref();
  }

  private connect(path: string, attempt = 0): Promise<void> {
    return new Promise((resolve, reject) => {
      const conn = createConnection(path);
      const fail = (err: Error) => {
        conn.destroy();
        if (attempt < 20) {
          // The broker is a fresh process: give it a moment to bind (200 ms × 20).
          setTimeout(() => this.connect(path, attempt + 1).then(resolve, reject), 200);
        } else {
          reject(new Error(`the pty broker did not answer on ${path}: ${err.message}`));
        }
      };
      conn.once("error", fail);
      conn.once("connect", () => {
        conn.off("error", fail);
        conn.setEncoding("utf8");
        conn.on("data", (chunk: string) => this.onChunk(chunk));
        conn.on("error", () => {
          this.conn = null;
        });
        conn.on("close", () => {
          this.conn = null;
        });
        this.conn = conn;
        resolve();
      });
    });
  }

  private onChunk(chunk: string): void {
    this.buffer += chunk;
    let nl: number;
    while ((nl = this.buffer.indexOf("\n")) >= 0) {
      const line = this.buffer.slice(0, nl);
      this.buffer = this.buffer.slice(nl + 1);
      if (!line.trim()) continue;
      let msg: any;
      try {
        msg = JSON.parse(line);
      } catch {
        continue;
      }
      this.next?.(msg);
    }
  }

  send(obj: Record<string, unknown>): void {
    if (!this.conn || this.conn.destroyed) return;
    this.conn.write(JSON.stringify(obj) + "\n");
  }

  /** Wait for the next message matching `want`, for at most `ms`. */
  await(want: (msg: any) => boolean, ms = 15_000): Promise<any> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.next = null;
        reject(new Error("the pty broker did not answer in time"));
      }, ms);
      this.next = (msg) => {
        if (!want(msg)) return;
        clearTimeout(timer);
        this.next = null;
        resolve(msg);
      };
    });
  }

  on(handler: (msg: any) => void): void {
    this.next = handler;
  }
}

const BROKER = new Broker();

export class TerminalRegistry {
  private sessions = new Map<string, Session>();
  private audit: (line: string) => void;

  constructor(audit?: (line: string) => void) {
    this.audit = audit ?? ((line) => defaultAudit(line));
  }

  countFor(owner: string): number {
    let n = 0;
    for (const s of this.sessions.values()) if (s.owner === owner) n++;
    return n;
  }

  async open(
    opts: { id: string; owner: string; cwd?: string; cols?: number; rows?: number },
    handlers: TerminalHandlers,
  ): Promise<OpenedTerminal> {
    if (!terminalsEnabled()) throw new Error("terminals are disabled on this seat (YMIR_TERMINAL=0)");
    if (this.countFor(opts.owner) >= MAX_SESSIONS_PER_USER) {
      throw new Error(`terminal limit reached (${MAX_SESSIONS_PER_USER}) — close one before opening another`);
    }
    this.close(opts.id, "replaced");

    await BROKER.ready();
    const cwd = opts.cwd && existsSync(opts.cwd) ? opts.cwd : defaultCwd();
    const reply = BROKER.await((m) => m && m.id === opts.id && (m.ev === "ready" || m.ev === "error"), 20_000);
    BROKER.send({
      op: "open",
      id: opts.id,
      cwd,
      cols: opts.cols && opts.cols > 0 ? opts.cols : DEFAULT_COLS,
      rows: opts.rows && opts.rows > 0 ? opts.rows : DEFAULT_ROWS,
    });
    const ready = await reply;
    if (ready.ev === "error") throw new Error(ready.m ?? "the pty broker refused");

    const now = Date.now();
    const timer = setInterval(() => {
      const s = this.sessions.get(opts.id);
      if (!s) return;
      if (Date.now() - s.lastActivity > IDLE_TIMEOUT_MS) {
        this.audit(`terminal idle-timeout: ${opts.id} (${opts.owner})`);
        this.close(opts.id, "idle");
      }
    }, Math.min(60_000, Math.max(5_000, Math.floor(IDLE_TIMEOUT_MS / 4))));
    timer.unref?.();

    const session: Session = {
      id: opts.id,
      owner: opts.owner,
      createdAt: now,
      lastActivity: now,
      timer,
      handlers,
    };
    this.sessions.set(opts.id, session);

    // Every broker event is routed to the session that owns the id.
    BROKER.on((msg) => {
      const s = this.sessions.get(msg?.id);
      if (!s) return;
      if (msg.ev === "o") {
        s.lastActivity = Date.now();
        s.handlers.onData(String(msg.d ?? ""));
      } else if (msg.ev === "exit") {
        clearInterval(s.timer);
        this.sessions.delete(msg.id);
        s.handlers.onExit({ exitCode: Number(msg.code ?? 0) });
      }
    });

    this.audit(`terminal open: ${opts.id} (${opts.owner}) shell=${ready.shell} cwd=${ready.cwd} pid=${ready.pid}`);
    return { id: opts.id, pid: Number(ready.pid ?? 0), shell: String(ready.shell ?? ""), cwd: String(ready.cwd ?? cwd) };
  }

  write(id: string, data: string): void {
    const s = this.sessions.get(id);
    if (!s) return;
    s.lastActivity = Date.now();
    BROKER.send({ op: "i", id, d: data });
  }

  resize(id: string, cols: number, rows: number): void {
    const s = this.sessions.get(id);
    if (!s || !Number.isFinite(cols) || !Number.isFinite(rows)) return;
    if (cols < 2 || rows < 2 || cols > 1000 || rows > 1000) return;
    BROKER.send({ op: "r", id, cols: Math.floor(cols), rows: Math.floor(rows) });
  }

  close(id: string, reason = "closed"): void {
    const s = this.sessions.get(id);
    if (!s) return;
    clearInterval(s.timer);
    this.sessions.delete(id);
    BROKER.send({ op: "close", id });
    this.audit(`terminal close: ${id} (${s.owner}) reason=${reason}`);
  }

  closeAll(reason = "shutdown"): void {
    for (const id of [...this.sessions.keys()]) this.close(id, reason);
  }

  ids(): string[] {
    return [...this.sessions.keys()];
  }
}

/**
 * The default audit writes a rune through the house's own ledger door, and otherwise names
 * the SKIP — a terminal that is not recorded is a door with no witness.
 */
function defaultAudit(line: string): void {
  try {
    const home = process.env.YMIR_HOME?.trim();
    const ledger = home ? join(home, "hodd/memory/runes_audit.md") : "";
    if (ledger && existsSync(ledger)) {
      appendFileSync(ledger, `\n- ${new Date().toISOString()} terminal — ${line}\n`);
      return;
    }
    console.error(`[terminal] SKIP audit (${line}) — no ledger resolved (YMIR_HOME)`);
  } catch (err) {
    console.error(`[terminal] audit failed: ${String((err as Error)?.message ?? err)}`);
  }
}

/** Diagnostics for the gate's own health surfaces (never a credential). */
export function terminalStatus(registry: TerminalRegistry): Record<string, unknown> {
  return {
    enabled: terminalsEnabled(),
    remoteAllowed: terminalsAllowRemote(),
    shell: shellFor(),
    cwd: defaultCwd(),
    socket: socketPath(),
    open: registry.ids().length,
    maxPerUser: MAX_SESSIONS_PER_USER,
    idleTimeoutMs: IDLE_TIMEOUT_MS,
  };
}

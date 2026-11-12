import { execFile } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import { env } from './env.js';
import type { OrgoComputer, OrgoScreen } from './orgo.js';

/**
 * The hall's own computer (BILSKIRNIR_DESK=local, the default): one Linux desktop in a container on
 * this machine, one Xvnc screen per agent, started and stopped by the door `house/desk.sh`.
 *
 * It answers the same calls the app makes of Orgo (see orgo.ts), so computer.ts, desk.ts and vnc.ts
 * keep one shape whichever computer is behind them. Commands reach the desk through `docker exec`;
 * the screen is reached as plain RFB on loopback, and vnc.ts does the password handshake itself, so
 * the password never reaches a browser.
 */

const APP = new URL('../../', import.meta.url).pathname;
const DOOR = path.join(APP, 'house', 'desk.sh');

export const deskConfig = {
  docker: process.env.DOCKER ?? 'docker',
  container: process.env.BILSKIRNIR_DESK_CONTAINER ?? 'bilskirnir-desk',
  /** Where the desk's RFB ports listen. Loopback by default; the desk is never a public door. */
  host: process.env.BILSKIRNIR_DESK_HOST ?? '127.0.0.1',
  vncBase: Number(process.env.BILSKIRNIR_DESK_VNC_BASE ?? 5990),
  passwordFile: path.join(process.env.BILSKIRNIR_DESK_DIR ?? path.join(APP, 'data', 'desk'), 'vnc.pass'),
};

/** The id the app records for this computer (Orgo's is a UUID; ours is the container's name). */
export const LOCAL_DESK_ID = `local:${deskConfig.container}`;

interface Run { code: number; stdout: string; stderr: string }

function run(file: string, args: string[], timeoutSec = 60, envVars?: NodeJS.ProcessEnv): Promise<Run> {
  return new Promise((resolve) => {
    execFile(file, args, { timeout: timeoutSec * 1000, maxBuffer: 32 * 1024 * 1024, env: envVars ?? process.env }, (err, stdout, stderr) => {
      const code = err ? (typeof (err as any).code === 'number' ? (err as any).code : 1) : 0;
      resolve({ code, stdout: String(stdout ?? ''), stderr: String(stderr ?? '') || (err && code !== 0 ? String(err.message) : '') });
    });
  });
}

const docker = (args: string[], timeoutSec = 60) => run(deskConfig.docker, args, timeoutSec);

/** Orgo screen id <-> X display number. The default screen is :99, "screen-100" is :100. */
const displayOf = (screen?: string) => (!screen || screen === 'default' ? 99 : Number(String(screen).replace('screen-', '')));
const screenIdOf = (n: number) => (n === 99 ? 'default' : `screen-${n}`);

async function containerStatus(): Promise<string> {
  const r = await docker(['inspect', '-f', '{{.State.Status}}', deskConfig.container], 15);
  return r.code === 0 ? r.stdout.trim() : 'absent';
}

async function screens(): Promise<OrgoScreen[]> {
  const r = await docker(['exec', deskConfig.container, 'desk-screen', 'list'], 20);
  if (r.code !== 0) throw new Error(`the desk does not answer: ${(r.stderr || r.stdout).trim().slice(0, 200)}`);
  return r.stdout.split('\n').map((l) => l.trim().split(/\s+/)).filter((p) => p.length >= 2 && /^\d+$/.test(p[0])).map(([n, size]) => {
    const [w, h] = size.split('x').map(Number);
    const num = Number(n);
    return { id: screenIdOf(num), display: `:${num}`, width: w || 0, height: h || 0, default: num === 99 };
  });
}

/** Start the desk through its door (builds the image the first time). */
async function door(verb: 'up' | 'down'): Promise<void> {
  const r = await run('bash', [DOOR, verb], 900);
  if (r.code !== 0) throw new Error(`the desk did not come ${verb}: ${(r.stdout + r.stderr).trim().split('\n').slice(-2).join(' ').slice(0, 300)}`);
}

export const localDesk = {
  async getComputer(_id: string): Promise<OrgoComputer> {
    const s = await containerStatus();
    // 'stopped' makes the panel wake it, which runs the door.
    return { id: LOCAL_DESK_ID, name: deskConfig.container, status: s === 'running' ? 'running' : 'stopped' };
  },
  start: (_id: string) => door('up'),
  resume: (_id: string) => door('up'),
  suspend: (_id: string) => door('down'),

  async vncPassword(_id: string): Promise<{ password: string }> {
    try {
      return { password: fs.readFileSync(deskConfig.passwordFile, 'utf8').trim() };
    } catch {
      throw new Error(`no VNC password at ${deskConfig.passwordFile} — run house/desk.sh up`);
    }
  },

  listScreens: (_id: string) => screens(),

  async createScreen(_id: string): Promise<OrgoScreen> {
    const taken = new Set((await screens()).map((s) => displayOf(s.id)));
    let n = 100;
    while (taken.has(n)) n++;
    const r = await docker(['exec', deskConfig.container, 'desk-screen', 'start', String(n)], 30);
    if (r.code !== 0) throw new Error(`could not open screen :${n} on the desk: ${(r.stderr || r.stdout).trim().slice(0, 200)}`);
    const made = (await screens()).find((s) => s.id === screenIdOf(n));
    if (!made) throw new Error(`screen :${n} did not appear on the desk`);
    return made;
  },

  async getScreen(_id: string, screen: string): Promise<OrgoScreen> {
    const found = (await screens()).find((s) => s.id === screen);
    if (!found) throw new Error(`screen ${screen} is not running on the desk`);
    return found;
  },

  async screenshot(_id: string, screen?: string): Promise<{ image: string; mime_type: string; width: number; height: number }> {
    const n = displayOf(screen);
    const r = await docker(['exec', '-e', `DISPLAY=:${n}`, deskConfig.container, 'sh', '-c', 'import -window root -quality 75 jpeg:- | base64 -w0'], 30);
    if (r.code !== 0 || !r.stdout.trim()) throw new Error(`no picture from screen :${n}`);
    return { image: r.stdout.trim(), mime_type: 'image/jpeg', width: 0, height: 0 };
  },

  /** Run a command on the desk, seeing the given screen's display. */
  async bash(_id: string, screen: string | undefined, command: string, timeout = 120): Promise<{ success: boolean; output: string; exit_code: number }> {
    const r = await docker(['exec', '-e', `DISPLAY=:${displayOf(screen)}`, deskConfig.container, 'bash', '-c', command], timeout + 10);
    return { success: r.code === 0, output: r.stdout + r.stderr, exit_code: r.code };
  },
};

/** The RFB port of a screen on the desk. */
export const rfbPortFor = (screenId: string) => deskConfig.vncBase + displayOf(screenId) - 99;

/**
 * A raw TCP connection to a desk screen, shaped like the ws upstream vnc.ts already pipes:
 * send(), close(), readyState, and the 'open' / 'message' / 'close' / 'error' events.
 */
export class TcpUpstream {
  static readonly OPEN = 1;
  private sock: net.Socket;
  private handlers: Record<string, ((...a: any[]) => void)[]> = {};
  readyState = 0;
  constructor(host: string, port: number) {
    this.sock = net.connect({ host, port });
    this.sock.on('connect', () => { this.readyState = TcpUpstream.OPEN; this.fire('open'); });
    this.sock.on('data', (d) => this.fire('message', d));
    this.sock.on('error', (e) => this.fire('error', e));
    this.sock.on('close', () => { this.readyState = 3; this.fire('close', 1000, Buffer.from('')); });
  }
  on(ev: string, fn: (...a: any[]) => void) { (this.handlers[ev] ??= []).push(fn); return this; }
  once(ev: string, fn: (...a: any[]) => void) {
    const wrap = (...a: any[]) => { this.handlers[ev] = (this.handlers[ev] ?? []).filter((f) => f !== wrap); fn(...a); };
    return this.on(ev, wrap);
  }
  send(b: Buffer) { if (this.readyState === TcpUpstream.OPEN) this.sock.write(b); }
  close() { this.sock.end(); this.sock.destroy(); }
  private fire(ev: string, ...a: any[]) { for (const f of [...(this.handlers[ev] ?? [])]) f(...a); }
}

export const deskIsLocal = () => env.desk === 'local';

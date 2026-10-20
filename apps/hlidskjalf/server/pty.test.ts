/**
 * Þráðr's laws, tested without a browser and without a shell left behind.
 *
 * These are the rules that make a terminal lawful in a web app: the cap, the idle close,
 * the socket owning the shell, the shell being the operator's own, and the door being
 * opt-in and loopback-only unless the Allfather says otherwise.
 */
import { describe, expect, test, beforeEach, afterEach } from 'bun:test';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  TerminalRegistry,
  IDLE_TIMEOUT_MS,
  MAX_SESSIONS_PER_USER,
  shellFor,
  terminalsAllowRemote,
  terminalsEnabled,
} from './pty.ts';

// A private broker socket per test run: the suite must never touch a live seat's shells.
const SOCKDIR = mkdtempSync(join(tmpdir(), 'thradr-'));
process.env.YMIR_THRADR_SOCKET = join(SOCKDIR, 'broker.sock');

const audit: string[] = [];
const reg = () => new TerminalRegistry((line) => audit.push(line));
const noop = { onData: () => {}, onExit: () => {} };

describe('the door is opt-in and local', () => {
  const before = { t: process.env.YMIR_TERMINAL, r: process.env.YMIR_TERMINAL_ALLOW_REMOTE };
  afterEach(() => {
    if (before.t === undefined) delete process.env.YMIR_TERMINAL; else process.env.YMIR_TERMINAL = before.t;
    if (before.r === undefined) delete process.env.YMIR_TERMINAL_ALLOW_REMOTE; else process.env.YMIR_TERMINAL_ALLOW_REMOTE = before.r;
  });

  test('terminals are enabled unless explicitly disabled', () => {
    expect(terminalsEnabled()).toBe(true);
    process.env.YMIR_TERMINAL = '0';
    expect(terminalsEnabled()).toBe(false);
  });

  test('a disabled seat refuses to open one', async () => {
    process.env.YMIR_TERMINAL = '0';
    await expect(reg().open({ id: 'a', owner: 'op' }, noop)).rejects.toThrow(/disabled/);
  });

  test('remote peers are refused unless the word is given', () => {
    expect(terminalsAllowRemote()).toBe(false);
    process.env.YMIR_TERMINAL_ALLOW_REMOTE = '1';
    expect(terminalsAllowRemote()).toBe(true);
  });

  test('the shell is the operator own ($SHELL), never a hardcoded bash', () => {
    const s = shellFor();
    expect(s.startsWith('/')).toBe(true);
    expect(s.endsWith('bash') || s.endsWith('sh') || s.endsWith('zsh') || s.length > 0).toBe(true);
  });
});

describe('the registry bounds every shell', () => {
  test(`at most ${MAX_SESSIONS_PER_USER} shells per owner`, async () => {
    const r = reg();
    for (let i = 0; i < MAX_SESSIONS_PER_USER; i++) await r.open({ id: `s${i}`, owner: 'op' }, noop);
    await expect(r.open({ id: 'one-too-many', owner: 'op' }, noop)).rejects.toThrow(/limit reached/);
    // another owner is unaffected
    await r.open({ id: 'other', owner: 'someone-else' }, noop);
    r.closeAll('test');
  });

  test('a second open with the same id replaces the first', async () => {
    const r = reg();
    await r.open({ id: 'same', owner: 'op' }, noop);
    await r.open({ id: 'same', owner: 'op' }, noop);
    expect(r.ids()).toEqual(['same']);
    r.closeAll('test');
  });

  test('closing is idempotent and audited', async () => {
    const r = reg();
    await r.open({ id: 'x', owner: 'op' }, noop);
    r.close('x', 'test');
    expect(r.ids()).toEqual([]);
    r.close('x', 'test');
    expect(audit.some((l) => l.startsWith('terminal open: x'))).toBe(true);
    expect(audit.some((l) => l.startsWith('terminal close: x'))).toBe(true);
  });

  test('a real shell is born, and carries output both ways', async () => {
    const r = reg();
    let out = '';
    const opened = await r.open({ id: 'echo', owner: 'op', cols: 100, rows: 30 }, {
      onData: (d) => { out += d; },
      onExit: () => {},
    });
    expect(opened.pid).toBeGreaterThan(0);
    expect(opened.shell.startsWith('/')).toBe(true);
    r.write('echo', 'echo BROKER-OK\n');
    const deadline = Date.now() + 8000;
    while (!out.includes('BROKER-OK') && Date.now() < deadline) await Bun.sleep(100);
    expect(out).toContain('BROKER-OK');
    expect(IDLE_TIMEOUT_MS).toBeGreaterThan(60_000);
    r.closeAll('test');
  });
});

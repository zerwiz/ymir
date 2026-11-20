import { join } from 'node:path';

type Options = { root: string; home: string };

const json = (data: unknown, status = 200) => Response.json(data, {
  status, headers: { 'cache-control': 'no-store' },
});

/** Rödd — the live voice. This door only drives `bin/voice/voice-door.sh`; it never
 * re-implements the pipeline, so the pane and the button start the same thing.
 * Access is the gate's existing local-owner policy, reused from the voice door. */
export function createRoddHandler({ root, home }: Options) {
  const door = join(root, 'bin/voice/voice-door.sh');
  const log = join(home, 'hodd/state/voice/host.log');

  async function run(args: string[], timeoutSeconds: number): Promise<{ code: number; out: string }> {
    const proc = Bun.spawn(['timeout', String(timeoutSeconds), door, ...args], {
      stdout: 'pipe', stderr: 'pipe', env: process.env,
    });
    const [out, err] = await Promise.all([
      new Response(proc.stdout).text(),
      new Response(proc.stderr).text(),
    ]);
    return { code: await proc.exited, out: `${out}${err}`.trim() };
  }

  /** Fire and forget: `start` seats a herdr pane and runs for as long as the voice
   * lives, so the request must not wait for it. */
  function detach(args: string[]): void {
    Bun.spawn(['setsid', door, ...args], {
      stdout: 'ignore', stderr: 'ignore', stdin: 'ignore',
      env: { ...process.env, YMIR_VOICE_DETACHED: '1' },
    });
  }

  return async function rodd(req: Request): Promise<Response> {
    const url = new URL(req.url);
    const action = url.pathname.replace('/api/rodd', '').replace(/^\//, '');
    if (action === '' || action === 'status') {
      const { code, out } = await run(['status'], 12);
      return json({ ok: code === 0, status: out, log });
    }
    if (action === 'log') {
      // one door: the same view the shell's `voice-door.sh log` prints (tool calls + turns)
      const { code, out } = await run(['log', '40'], 20);
      if (code === 0 && out) return json({ ok: true, activity: out });
      try {
        const text = await Bun.file(log).text();
        return json({ ok: true, activity: text.split('\n').slice(-40).join('\n') });
      } catch {
        return json({ ok: false, error: 'no voice log on this seat', log });
      }
    }
    if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405);
    if (action === 'start') {
      detach(['start']);
      return json({ ok: true, started: true, note: 'seating Rödd in a herdr pane; poll status' });
    }
    if (action === 'stop') {
      const withHost = url.searchParams.get('host') === '1';
      const { code, out } = await run(withHost ? ['stop', '--host'] : ['stop'], 20);
      return json({ ok: code === 0, status: out });
    }
    return json({ error: 'unknown action', actions: ['status', 'start', 'stop', 'log'] }, 404);
  };
}

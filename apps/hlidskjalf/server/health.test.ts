import { describe, expect, test } from 'bun:test';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { readSoakHealth, BUDGETS } from './health.ts';

/* A planted world: a temporary $YMIR_HOME with a soak ledger and app soaks, so
 * every verdict is proved without touching this machine's real rows. */

const T0 = Date.parse('2026-11-14T04:00:00Z');
const iso = (ms: number) => new Date(ms).toISOString().replace('.000Z', 'Z');

function home(): string {
  const dir = mkdtempSync(join(tmpdir(), 'soak-health-'));
  mkdirSync(join(dir, 'state', 'soak', 'services'), { recursive: true });
  return dir;
}

function writeLedger(homeDir: string, rows: Array<Record<string, unknown>>) {
  const path = join(homeDir, 'state', 'soak', 'services', '2026-11-14.jsonl');
  writeFileSync(path, rows.map((r) => JSON.stringify(r)).join('\n') + '\n');
}

/** Six service samples, five minutes apart, ending at the fixed clock. */
function serviceRows(
  name: string,
  opts: { rss: number[]; fds?: number[]; watches?: number[]; children?: number[]; restarts?: number[]; zombies?: number[] },
) {
  const rows: Array<Record<string, unknown>> = [];
  for (let i = 0; i < opts.rss.length; i++) {
    rows.push({
      ts: iso(T0 - (opts.rss.length - 1 - i) * 5 * 60_000),
      pass: 'P1',
      kind: 'service',
      name,
      state: 'active',
      sub: 'running',
      rss_kb: opts.rss[i],
      fds: opts.fds?.[i] ?? 8,
      inotify_watches: opts.watches?.[i] ?? 0,
      pids: opts.children?.[i] ?? 1,
      zombies: opts.zombies?.[i] ?? 0,
      gpu_mib: 0,
      restarts: opts.restarts?.[i] ?? 0,
    });
  }
  rows.push({ ts: iso(T0), pass: 'P1', kind: 'pass', targets: 1, units_seen: 1, apps: 0, seconds: 1 });
  return rows;
}

const six = (start: number, end: number) =>
  Array.from({ length: 6 }, (_, i) => Math.round(start + ((end - start) * i) / 5));

describe('the service ledger', () => {
  test('no ledger is named, never an empty quiet machine', () => {
    const dir = mkdtempSync(join(tmpdir(), 'soak-none-'));
    const h = readSoakHealth({ homeDir: dir, appNames: ['hlidskjalf'], now: T0 });
    expect(h.services).toHaveLength(0);
    expect(h.error).toContain('no soak ledger');
    expect(h.apps[0]).toMatchObject({ app: 'hlidskjalf', present: false, verdict: 'unknown' });
  });

  test('a flat service holds', () => {
    const dir = home();
    writeLedger(dir, serviceRows('calm.service', { rss: six(100_000, 101_000) }));
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.services).toHaveLength(1);
    expect(h.services[0].verdict).toBe('holds');
    expect(h.services[0].samples).toBe(6);
  });

  test('RSS past 5 % grows, and the reason names the number', () => {
    const dir = home();
    writeLedger(dir, serviceRows('leaky.service', { rss: six(100_000, 150_000) }));
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.services[0].verdict).toBe('grows');
    expect(h.services[0].rssPct).toBeCloseTo(50, 0);
    expect(h.services[0].why).toContain('RSS +50');
  });

  test('file descriptors that never close grow even when RSS is flat', () => {
    const dir = home();
    writeLedger(dir, serviceRows('fds.service', { rss: six(100_000, 100_000), fds: [8, 9, 11, 14, 18, 26] }));
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.services[0].verdict).toBe('grows');
    expect(h.services[0].why).toContain('file descriptors +18');
  });

  test('inotify watches and children are counted, not hidden', () => {
    const dir = home();
    writeLedger(dir, serviceRows('watch.service', { rss: six(100_000, 100_000), watches: six(0, 200), children: six(1, 4) }));
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.services[0].verdict).toBe('grows');
    expect(h.services[0].why).toContain('inotify watches +200');
    expect(h.services[0].why).toContain('children +3');
  });

  test('three restarts in the window is the restart verdict', () => {
    const dir = home();
    writeLedger(dir, serviceRows('loop.service', { rss: six(100_000, 100_000), restarts: [0, 1, 1, 2, 3, 4] }));
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.services[0].verdict).toBe('restarts');
    expect(h.services[0].restartsInWindow).toBe(4);
  });

  test('a restart counter that resets on a stop is summed, not subtracted', () => {
    const dir = home();
    // systemd resets NRestarts when the unit is stopped: 2 -> 0 -> 2 -> 0
    writeLedger(dir, serviceRows('reset.service', { rss: six(100_000, 100_000), restarts: [2, 0, 2, 0, 2, 2] }));
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.services[0].restartsInWindow).toBe(4);
    expect(h.services[0].verdict).toBe('restarts');
  });

  test('the ward`s storm row is the verdict even below the count', () => {
    const dir = home();
    const rows = serviceRows('stormed.service', { rss: six(100_000, 100_000) });
    rows.push({
      ts: iso(T0), pass: 'P1', kind: 'storm', name: 'stormed.service', action: 'stopped',
      verdict: 'stop', restarts: 28, source: 'journal', window_minutes: 60, threshold: 10,
      last_error: 'stormed.service: Failed with result exit-code',
    });
    writeLedger(dir, rows);
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.services[0].verdict).toBe('restarts');
    expect(h.services[0].why).toContain('28 restarts');
    expect(h.storms[0]).toMatchObject({ name: 'stormed.service', restarts: 28, threshold: 10 });
  });

  test('a stopped timer is stale and says so, and the trend still reads', () => {
    const dir = home();
    writeLedger(dir, serviceRows('old.service', { rss: six(100_000, 150_000) }));
    const h = readSoakHealth({ homeDir: dir, now: T0 + 3 * 60 * 60_000 });
    expect(h.stale).toBe(true);
    expect(h.ageMinutes).toBe(180);
    expect(h.services[0].verdict).toBe('grows');
  });

  test('the newest pass, not an old name, decides which services are shown', () => {
    const dir = home();
    const rows = serviceRows('current.service', { rss: six(100_000, 100_000) });
    // an old pass that named a service now gone must not resurrect it
    rows.unshift({
      ts: iso(T0 - 60 * 60_000), pass: 'P0', kind: 'service', name: 'retired.service', state: 'active',
      sub: 'running', rss_kb: 1, fds: 1, inotify_watches: 0, pids: 1, zombies: 0, gpu_mib: 0, restarts: 0,
    });
    writeLedger(dir, rows);
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.services.map((s) => s.name)).toEqual(['current.service']);
  });
});

describe('an app`s last soak (the soak harness`s own rows)', () => {
  function appHome(app: string, rows: Array<Record<string, unknown>>) {
    const dir = home();
    mkdirSync(join(dir, 'state', 'soak', app), { recursive: true });
    writeFileSync(join(dir, 'state', 'soak', app, '2026-11-14.jsonl'), rows.map((r) => JSON.stringify(r)).join('\n') + '\n');
    return dir;
  }
  const at = (s: number) => iso(T0 - (60 - s) * 1000);
  const raise = { ts: at(0), app: 'x', kind: 'raise', cycles: 5, idle_seconds: 90, sample_seconds: 15 };
  const baseline = (o: Record<string, unknown> = {}) => ({ ts: at(3), app: 'x', kind: 'baseline', rss_mb: 200, heap_mb: 40, fds: 40, watches: 2, children: 2, zombies: 0, gpu_mb: 0, ...o });
  const after = (o: Record<string, unknown> = {}) => ({ ts: at(20), app: 'x', kind: 'after_cycles', rss_mb: 200, heap_mb: 40, fds: 40, watches: 2, children: 2, zombies: 0, gpu_mb: 0, ...o });
  const sample = (s: number, o: Record<string, unknown> = {}) => ({ ts: at(20 + s), app: 'x', kind: 'sample', rss_mb: 200, heap_mb: 40, fds: 40, watches: 2, children: 2, zombies: 0, gpu_mb: 0, ...o });
  const judge = (verdict: string, leaks: string[] = [], growth: Record<string, unknown> = {}) => ({ ts: at(59), app: 'x', kind: 'judge', verdict, leaks, growth });

  test('the harness judged it a pass: holds', () => {
    const dir = appHome('calm', [raise, baseline(), after(), sample(1), sample(2), judge('pass')]);
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.apps[0]).toMatchObject({ app: 'calm', present: true, verdict: 'holds', applied: 'cycles', cycles: 5 });
    expect(h.apps[0].why).toContain('pass');
  });

  test('the harness judged it a leak: grows, in its own words', () => {
    const dir = appHome('leaky', [
      raise, baseline(), after({ rss_mb: 240, fds: 58 }),
      sample(1), sample(2), judge('leak', ['rss_cycle_growth', 'fd_growth'], { rss_cycle_pct: 20, fds_cycle: 18 }),
      { ts: at(58), app: 'x', kind: 'finding', leak: 'rss_cycle_growth', detail: 'RSS grew 20 % over 5 passes of every page (budget 10 %)' },
      { ts: at(58), app: 'x', kind: 'finding', leak: 'fd_growth', detail: '18 descriptors were opened per full pass and never closed' },
    ]);
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.apps[0].verdict).toBe('grows');
    expect(h.apps[0].why).toContain('RSS grew 20 %');
    expect(h.apps[0].why).toContain('18 descriptors');
    expect(h.apps[0].rssPct).toBe(20);
  });

  test('a run with no judge row is judged here and says unjudged', () => {
    const dir = appHome('unjudged', [raise, baseline(), after({ rss_mb: 260 }), sample(1)]);
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.apps[0].verdict).toBe('grows');
    expect(h.apps[0].why).toContain('unjudged');
    expect(h.apps[0].rssPct).toBe(30);
  });

  test('a soak still being written has no verdict yet, and says so', () => {
    const dir = appHome('running', [raise, { ts: at(3), app: 'x', kind: 'boot', rss_mb: 300, main_cpu_pct: 20 }]);
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.apps[0].verdict).toBe('unknown');
    expect(h.apps[0].why).toMatch(/running|no baseline/);
  });

  test('a skipped soak names its reason', () => {
    const dir = appHome('busy', [{ ts: at(0), app: 'x', kind: 'skip', reason: 'desk call' }]);
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.apps[0].verdict).toBe('unknown');
    expect(h.apps[0].why).toContain('desk call');
  });

  test('a not-responding dialog is never a pass', () => {
    const dir = appHome('frozen', [raise, baseline(), after(), sample(1, { dialogs: ['Not Responding'], max_task: 2500 })]);
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.apps[0].verdict).toBe('grows');
    expect(h.apps[0].why).toContain('not-responding');
    expect(h.apps[0].maxLongTaskMs).toBe(2500);
  });

  test('the last run, not an earlier one in the same day, is the verdict', () => {
    const dir = appHome('twice', [
      // run 1 — a leak
      raise, baseline(), after({ rss_mb: 400 }), sample(1), judge('leak', ['rss_cycle_growth']),
      { ts: at(59), app: 'x', kind: 'finding', leak: 'rss_cycle_growth', detail: 'RUN ONE leaked' },
      // run 2 — clean, raised again after the first finished
      { ts: at(70), app: 'x', kind: 'raise', cycles: 5, idle_seconds: 90 },
      { ts: at(73), app: 'x', kind: 'baseline', rss_mb: 200, heap_mb: 40, fds: 40, watches: 2, children: 2, zombies: 0 },
      { ts: at(90), app: 'x', kind: 'after_cycles', rss_mb: 202, heap_mb: 40, fds: 40, watches: 2, children: 2, zombies: 0 },
      { ts: at(100), app: 'x', kind: 'sample', rss_mb: 202, fds: 40, watches: 2, children: 2, zombies: 0 },
      { ts: at(110), app: 'x', kind: 'judge', verdict: 'pass', leaks: [] },
    ]);
    const h = readSoakHealth({ homeDir: dir, now: T0 + 200_000 });
    expect(h.apps[0].verdict).toBe('holds');
    expect(h.apps[0].why).not.toContain('RUN ONE');
    expect(h.apps[0].rssStartMb).toBe(200);
  });

  test('a lone state file is not an app', () => {
    const dir = home();
    writeFileSync(join(dir, 'state', 'soak', 'storm-state.json'), '{}');
    const h = readSoakHealth({ homeDir: dir, now: T0 });
    expect(h.apps.find((a) => a.app.includes('storm-state'))).toBeUndefined();
  });

  test('an app with no soak says so and carries the sampler`s last figure', () => {
    const dir = home();
    const rows = serviceRows('some.service', { rss: six(100_000, 100_000) });
    rows.push({ ts: iso(T0), pass: 'P1', kind: 'app', scope: 'app', name: 'hlidskjalf', state: 'active', rss_kb: 300_000, fds: 30, inotify_watches: 1, pids: 2, gpu_mib: 0, restarts: 0 });
    writeLedger(dir, rows);
    const h = readSoakHealth({ homeDir: dir, appNames: ['hlidskjalf'], now: T0 });
    const app = h.apps.find((a) => a.app === 'hlidskjalf')!;
    expect(app.present).toBe(false);
    expect(app.verdict).toBe('unknown');
    expect(app.why).toContain('no soak yet');
    expect(app.sampled?.rssMb).toBeCloseTo(293, 0);
  });
});

describe('the budgets themselves', () => {
  test('they are plan 286 §5`s first numbers', () => {
    expect(BUDGETS).toMatchObject({ idleMinutes: 30, rssPctIdle: 5, rssPctCycles: 10, heapMbIdle: 2, heapMbCycles: 5, restartsPerHour: 3 });
  });
});

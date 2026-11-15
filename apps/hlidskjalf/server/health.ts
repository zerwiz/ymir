/**
 * Health — the leak ledger and the last soak of every app, read as a PERSON reads
 * them (plan 286 P6, RULES/52).
 *
 * Plan 286 measures the house two ways, and this module reads both:
 *
 *   services — the sampler (`bin/ward/soak-sampler.sh`) writes one JSON row per
 *              house service every five minutes into
 *              `$YMIR_HOME/state/soak/services/<YYYY-MM-DD>.jsonl`: RSS, file
 *              descriptors, inotify watches, child processes, GPU memory and the
 *              unit's restart count. A `kind:"pass"` row closes each pass and a
 *              `kind:"storm"` row is the restart ward's record.
 *
 *   apps     — the soak harness (`bin/gates/soak.sh <app>`) writes its own rows
 *              into `$YMIR_HOME/state/soak/<app>/<YYYY-MM-DD>.jsonl` while it
 *              raises the app, drives its pages N times and lets it idle. The
 *              writer's shape is read exactly as it lands (see `judgeApp` below:
 *              `raise`/`boot`/`baseline`/`cycle`/`after_cycles`/`sample`, then a
 *              `judge` row whose word IS plan 286 §5 already applied). An app
 *              with no directory is reported as "no soak yet" — never as a pass,
 *              never as a crash — and the sampler's own last reading of it is
 *              shown beside, so the row is never empty.
 *
 * THE BUDGETS are plan 286 §5 ("first numbers, to be approved"), copied here as
 * documented defaults so a page and the plan can never drift: RSS growth under
 * 5 % idle and under 10 % after 20 cycles; JS heap flat (under 2 MB idle, under
 * 5 MB after cycles); file descriptors flat; inotify watches flat; children flat
 * and no zombie; no main-thread task over 200 ms at idle and none over 1 s ever;
 * no not-responding dialog; a service under 3 restarts an hour. The app soak's
 * own `judge` row is preferred when it exists; §5 is applied here only when the
 * run carries baseline and after-cycles rows but no judge row (and the row says
 * `unjudged`).
 *
 * Every field is optional and every unreadable shape degrades to `unknown` with
 * the reason — never to a crash, never to an invented number.
 */
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

/* ---- the budgets (plan 286 §5) ------------------------------------------- */
export interface SoakBudgets {
  idleMinutes: number;
  rssPctIdle: number;
  rssPctCycles: number;
  heapMbIdle: number;
  heapMbCycles: number;
  longTaskMsIdle: number;
  longTaskMsCycles: number;
  restartsPerHour: number;
  sampleIntervalMinutes: number;
}

export const BUDGETS: SoakBudgets = {
  idleMinutes: 30,
  rssPctIdle: 5,
  rssPctCycles: 10,
  heapMbIdle: 2,
  heapMbCycles: 5,
  longTaskMsIdle: 200,
  longTaskMsCycles: 1000,
  restartsPerHour: 3,
  sampleIntervalMinutes: 5,
};

/**
 * The three words the page says, and no fourth:
 *   holds    — every budget above is inside its bound;
 *   grows    — something climbed past its bound (RSS, heap, fds, watches,
 *              children, a main-thread task, or a not-responding dialog);
 *   restarts — the unit restarted past its bound, or the ward stopped it.
 * `unknown` is the honest fourth answer when there is not enough to judge, and
 * the row says why: no soak yet, fewer than two samples, an unreadable ledger.
 */
export type Verdict = 'holds' | 'grows' | 'restarts' | 'unknown';

/** One service's trend over the ledger's own last window. */
export interface ServiceTrend {
  name: string;
  state: string;
  sub: string;
  samples: number;
  windowMinutes: number;
  firstTs: string;
  lastTs: string;
  /** RSS as the window opened, now, and its peak, in MiB. */
  rssStartMb: number | null;
  rssNowMb: number | null;
  rssPeakMb: number | null;
  rssPct: number | null;
  fdsStart: number | null;
  fdsNow: number | null;
  fdsDelta: number | null;
  watchesStart: number | null;
  watchesNow: number | null;
  watchesDelta: number | null;
  childrenStart: number | null;
  childrenNow: number | null;
  childrenDelta: number | null;
  zombies: number;
  gpuMib: number | null;
  restarts: number;
  restartsInWindow: number;
  verdict: Verdict;
  why: string;
}

/** One app's last soak, and the sampler's last reading as a hint when it has none. */
export interface AppHealth {
  app: string;
  /** true when `state/soak/<app>/` holds at least one readable row. */
  present: boolean;
  date: string;
  samples: number;
  windowMinutes: number;
  rssPct: number | null;
  rssStartMb: number | null;
  rssNowMb: number | null;
  heapMbDelta: number | null;
  fdsDelta: number | null;
  watchesDelta: number | null;
  childrenDelta: number | null;
  gpuMib: number | null;
  maxLongTaskMs: number | null;
  notResponding: number;
  cycles: number;
  /** the budgets that applied to this run (cycles column at 20 or more). */
  applied: 'idle' | 'cycles';
  verdict: Verdict;
  why: string;
  /** false when no soak directory exists — the sampler's figures, if any, follow. */
  sampled?: { rssMb: number | null; fds: number | null; watches: number | null; children: number | null; gpuMib: number | null; state: string } | null;
}

export interface SoakHealth {
  /** the directory the rows are read from, so a reader can find them. */
  state: string;
  budget: SoakBudgets;
  /** the window the service trend is measured over, in minutes. */
  windowMinutes: number;
  /** the newest pass the ledger holds, and how long ago it landed. */
  lastPass: string;
  ageMinutes: number | null;
  passes: number;
  /** true when the ledger has not moved for more than three sample intervals. */
  stale: boolean;
  services: ServiceTrend[];
  apps: AppHealth[];
  /** the restart ward's recent rows, so a "restarts" verdict names the stop. */
  storms: Array<{ name: string; ts: string; action: string; restarts: number; threshold: number; lastError: string }>;
  error?: string;
}

/* ---- small readers ------------------------------------------------------- */
function readText(path: string): string {
  try {
    return readFileSync(path, 'utf8');
  } catch {
    return '';
  }
}

/** Every `*.jsonl` in a directory, oldest first by name (names are dates). */
function jsonlFiles(dir: string): string[] {
  if (!existsSync(dir)) return [];
  try {
    return readdirSync(dir)
      .filter((f) => f.endsWith('.jsonl'))
      .sort()
      .map((f) => join(dir, f));
  } catch {
    return [];
  }
}

/** Parse a JSONL file into objects, skipping a truncated or malformed line. */
function parseJsonl(path: string, maxLines = 60_000): Array<Record<string, unknown>> {
  const out: Array<Record<string, unknown>> = [];
  const text = readText(path);
  if (!text) return out;
  const lines = text.split('\n');
  const start = Math.max(0, lines.length - maxLines);
  for (let i = start; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;
    try {
      const row = JSON.parse(line);
      if (row && typeof row === 'object') out.push(row as Record<string, unknown>);
    } catch {
      // a half-written last line is not a fault worth a row
    }
  }
  return out;
}

const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null);
const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const tsMs = (v: unknown): number => {
  const t = Date.parse(str(v));
  return Number.isFinite(t) ? t : NaN;
};

const mib = (kb: number | null): number | null => (kb == null ? null : Math.round((kb / 1024) * 10) / 10);
const pct = (start: number | null, now: number | null): number | null =>
  start == null || now == null || start === 0 ? null : Math.round(((now - start) / start) * 1000) / 10;

/* ---- the service ledger -------------------------------------------------- */
interface ServiceRow {
  ts: string;
  pass: string;
  name: string;
  state: string;
  sub: string;
  rssKb: number | null;
  fds: number | null;
  watches: number | null;
  children: number | null;
  zombies: number;
  gpuMib: number | null;
  restarts: number;
}

function serviceRow(row: Record<string, unknown>): ServiceRow | null {
  const name = str(row.name);
  if (!name) return null;
  return {
    ts: str(row.ts),
    pass: str(row.pass),
    name,
    state: str(row.state),
    sub: str(row.sub),
    rssKb: num(row.rss_kb),
    fds: num(row.fds),
    watches: num(row.inotify_watches),
    children: num(row.pids),
    zombies: num(row.zombies) ?? 0,
    gpuMib: num(row.gpu_mib),
    restarts: num(row.restarts) ?? 0,
  };
}

/** Sum the positive steps of a restart counter (systemd resets it on a stop). */
function restartSteps(rows: ServiceRow[]): number {
  let total = 0;
  for (let i = 1; i < rows.length; i++) {
    const step = rows[i].restarts - rows[i - 1].restarts;
    if (step > 0) total += step;
  }
  return total;
}

function judgeService(rows: ServiceRow[], storms: SoakHealth['storms'], budget: SoakBudgets): ServiceTrend {
  const first = rows[0];
  const last = rows[rows.length - 1];
  const windowMinutes = Math.max(1, Math.round((tsMs(last.ts) - tsMs(first.ts)) / 60_000));
  const restartsInWindow = restartSteps(rows);
  const rssPct = pct(first.rssKb, last.rssKb);
  const fdsDelta = first.fds != null && last.fds != null ? last.fds - first.fds : null;
  const watchesDelta = first.watches != null && last.watches != null ? last.watches - first.watches : null;
  const childrenDelta = first.children != null && last.children != null ? last.children - first.children : null;
  const rssPeakKb = rows.reduce<number | null>((peak, r) => (r.rssKb != null && (peak == null || r.rssKb > peak) ? r.rssKb : peak), null);
  const storm = storms.find((s) => s.name === last.name);

  const grows: string[] = [];
  if (rssPct != null && rssPct > budget.rssPctIdle) grows.push(`RSS +${rssPct}% (budget under ${budget.rssPctIdle}%)`);
  if (fdsDelta != null && fdsDelta > 0) grows.push(`file descriptors +${fdsDelta}`);
  if (watchesDelta != null && watchesDelta > 0) grows.push(`inotify watches +${watchesDelta}`);
  if (childrenDelta != null && childrenDelta > 0) grows.push(`children +${childrenDelta}`);
  if (last.zombies > 0) grows.push(`${last.zombies} zombie${last.zombies === 1 ? '' : 's'}`);

  let verdict: Verdict = 'holds';
  let why = 'inside every budget';
  if (rows.length < 2) {
    verdict = 'unknown';
    why = 'one sample in the window — the trend needs two';
  } else if (storm) {
    verdict = 'restarts';
    why = `the ward stopped it after ${storm.restarts} restarts (limit ${storm.threshold}/h)`;
  } else if (restartsInWindow >= budget.restartsPerHour) {
    verdict = 'restarts';
    why = `${restartsInWindow} restarts in ${windowMinutes} min (budget under ${budget.restartsPerHour} an hour)`;
  } else if (grows.length) {
    verdict = 'grows';
    why = grows.join(' · ');
  }

  return {
    name: last.name,
    state: last.state,
    sub: last.sub,
    samples: rows.length,
    windowMinutes,
    firstTs: first.ts,
    lastTs: last.ts,
    rssStartMb: mib(first.rssKb),
    rssNowMb: mib(last.rssKb),
    rssPeakMb: mib(rssPeakKb),
    rssPct,
    fdsStart: first.fds,
    fdsNow: last.fds,
    fdsDelta,
    watchesStart: first.watches,
    watchesNow: last.watches,
    watchesDelta,
    childrenStart: first.children,
    childrenNow: last.children,
    childrenDelta,
    zombies: last.zombies,
    gpuMib: last.gpuMib,
    restarts: last.restarts,
    restartsInWindow,
    verdict,
    why,
  };
}

/* ---- the app soak -------------------------------------------------------- *
 * The writer is `bin/gates/soak.sh` (plan 286 P1/P2), and the rows are ITS
 * contract, read here as they land:
 *
 *   {"ts":…,"app":"sessrumnir","kind":"raise","cycles":5,"idle_seconds":90,…}
 *   {"ts":…,"kind":"boot"|"baseline"|"cycle"|"after_cycles"|"sample",
 *    "rss_mb":807.9,"heap_mb":7.82,"fds":208,"watches":5946,"children":5,
 *    "threads":79,"zombies":0,"gpu_mb":0,"max_task":413,"dialogs":[],…}
 *   {"ts":…,"kind":"judge","verdict":"pass"|"leak","leaks":[…],"growth":{…}}
 *   {"ts":…,"kind":"finding","leak":"rss_cycle_growth","detail":"RSS grew …"}
 *   {"ts":…,"kind":"skip","reason":"desk call"|"not listening"}
 *
 * The `judge` row is plan 286 §5 already applied by the harness, so its word is
 * the verdict: `pass` holds, `leak` grows, and the finding rows say why in the
 * harness's own words. A run that has not judged yet (the ledger is being
 * written as this page reads it) is `unknown`, with its numbers shown; if it
 * has baseline and after-cycles rows but no judge row, §5 is applied here and
 * the row says `unjudged`.
 */
function leakWords(names: string[]): string[] {
  const words: Record<string, string> = {
    rss_cycle_growth: 'RSS grew over the page cycles',
    js_heap_cycle_growth: 'the JS heap grew over the cycles',
    fd_growth: 'file descriptors were opened and never closed',
    watch_growth: 'inotify watches were added and never released',
    child_growth: 'child processes outlived their request',
    zombie_children: 'zombies under the app',
    rss_idle_growth: 'RSS grew while idle',
    js_heap_idle_growth: 'the JS heap grew while idle',
    fd_growth_idle: 'file descriptors opened while idle',
    watch_growth_idle: 'inotify watches appeared while idle',
    main_thread_idle_task: 'a main-thread task ran too long while idle',
    main_thread_cycle_task: 'a main-thread task ran too long',
    not_responding: 'the compositor raised a not-responding dialog',
    startup_freeze: 'the window froze during boot',
    startup_rss: 'RSS was high during boot',
    forbidden_watch_path: 'a watcher crossed into a forbidden shelf',
  };
  return names.map((n) => words[n] ?? n.replace(/_/g, ' '));
}

const lastOf = (rows: Array<Record<string, unknown>>, kind: string) => rows.filter((r) => str(r.kind) === kind).at(-1);

function longTasksOf(row: Record<string, unknown> | undefined): number {
  if (!row) return 0;
  const list = Array.isArray(row.long_tasks) ? (row.long_tasks as Array<Record<string, unknown>>) : [];
  const worst = list.reduce((m, t) => Math.max(m, num(t.duration) ?? 0), 0);
  return Math.max(worst, num(row.max_task) ?? 0);
}

function judgeApp(app: string, rows: Array<Record<string, unknown>>, budget: SoakBudgets): AppHealth {
  const all = rows.filter((r) => str(r.ts)).sort((a, b) => tsMs(a.ts) - tsMs(b.ts));
  // ONE DAY'S FILE MAY HOLD SEVERAL RUNS. "The last soak" is the last RUN, so a
  // new `raise` row starts a clean slate: an earlier run's findings must never
  // be laid on this one's verdict.
  const lastRaise = all.map((r) => str(r.kind)).lastIndexOf('raise');
  const lastBaselineStart = all.map((r) => str(r.kind)).lastIndexOf('baseline');
  const runAt = lastRaise >= 0 ? lastRaise : lastBaselineStart;
  const sorted = runAt > 0 ? all.slice(runAt) : all;
  const baseline = lastOf(sorted, 'baseline');
  const after = lastOf(sorted, 'after_cycles');
  const samples = sorted.filter((r) => str(r.kind) === 'sample');
  const last = samples.at(-1) ?? after ?? baseline;
  const judge = lastOf(sorted, 'judge');
  const skip = lastOf(sorted, 'skip') ?? lastOf(sorted, 'raise_failed');
  const raise = lastOf(sorted, 'raise');
  const cycleRows = sorted.filter((r) => str(r.kind) === 'cycle');
  const findings = sorted.filter((r) => str(r.kind) === 'finding');
  const growth = (judge?.growth && typeof judge.growth === 'object' ? judge.growth : {}) as Record<string, unknown>;

  const cycles = cycleRows.length || num(raise?.cycles) || 0;
  const applied: 'idle' | 'cycles' = after || cycles > 0 ? 'cycles' : 'idle';
  const rssStartMb = num(baseline?.rss_mb);
  // The growth that §5 judges is baseline → AFTER THE CYCLES, so the pair shown
  // beside it must be that pair; an idle-only run falls back to its last sample.
  const rssNowMb = num(after?.rss_mb) ?? num(last?.rss_mb);
  const rssPct = num(growth.rss_cycle_pct) ?? pct(rssStartMb, num(after?.rss_mb));
  const heapMbDelta = num(growth.heap_cycle_mb)
    ?? (num(baseline?.heap_mb) != null && num(after?.heap_mb) != null
      ? Math.round(((num(after?.heap_mb) as number) - (num(baseline?.heap_mb) as number)) * 100) / 100
      : null);
  const fdsDelta = num(growth.fds_cycle) ?? (num(baseline?.fds) != null && num(after?.fds) != null ? (num(after?.fds) as number) - (num(baseline?.fds) as number) : null);
  const watchesDelta = num(growth.watches_cycle) ?? (num(baseline?.watches) != null && num(after?.watches) != null ? (num(after?.watches) as number) - (num(baseline?.watches) as number) : null);
  const childrenDelta = num(growth.children_cycle) ?? (num(baseline?.children) != null && num(after?.children) != null ? (num(after?.children) as number) - (num(baseline?.children) as number) : null);
  const gpuMib = num(after?.gpu_mb) ?? num(last?.gpu_mb);
  const maxLongTaskMs = sorted.reduce((m, r) => Math.max(m, longTasksOf(r)), 0) || null;
  const notResponding = sorted.reduce((m, r) => Math.max(m, Array.isArray(r.dialogs) ? (r.dialogs as unknown[]).length : 0), 0);
  const spanStart = tsMs(baseline?.ts ?? sorted[0]?.ts);
  const spanEnd = tsMs(last?.ts);
  const windowMinutes = Number.isFinite(spanStart) && Number.isFinite(spanEnd) ? Math.max(1, Math.round((spanEnd - spanStart) / 60_000)) : 0;
  const date = str(sorted[0]?.date) || (Number.isFinite(spanEnd) ? new Date(spanEnd).toISOString().slice(0, 10) : '');

  const base: AppHealth = {
    app, present: true, date, samples: samples.length + (after ? 1 : 0), windowMinutes,
    rssPct, rssStartMb, rssNowMb, heapMbDelta, fdsDelta, watchesDelta, childrenDelta, gpuMib,
    maxLongTaskMs, notResponding, cycles, applied, verdict: 'unknown', why: '',
  };

  if (skip) {
    const reason = str(skip.reason) || str(skip.kind) || 'skipped';
    return { ...base, verdict: 'unknown', why: `the soak was skipped: ${reason}` };
  }
  if (!baseline && !judge) {
    return { ...base, verdict: 'unknown', why: sorted.length ? 'the soak wrote no baseline — nothing to judge' : 'the soak file holds no rows' };
  }
  if (judge) {
    const declared = str(judge.verdict);
    const leakNames = Array.isArray(judge.leaks) ? (judge.leaks as unknown[]).map(String) : [];
    const details = findings.map((f) => str(f.detail)).filter(Boolean);
    if (declared === 'pass') {
      return { ...base, verdict: 'holds', why: `the soak judged it a pass (${cycleRows.length} passes of every page, ${samples.length} idle samples)` };
    }
    return {
      ...base, verdict: 'grows',
      why: details.length ? details.join(' · ') : leakWords(leakNames).join(' · ') || 'the soak found a leak',
    };
  }

  // No judge row yet. If the run has reached after-cycles, judge it here with §5
  // and SAY SO — never pretend the harness spoke.
  if (after) {
    const rssBudget = budget.rssPctCycles;
    const grows: string[] = [];
    if (rssPct != null && rssPct > rssBudget) grows.push(`RSS +${rssPct}% over the cycles (budget under ${rssBudget}%)`);
    if (heapMbDelta != null && heapMbDelta > budget.heapMbCycles) grows.push(`JS heap +${heapMbDelta} MB (budget under ${budget.heapMbCycles} MB)`);
    if (fdsDelta != null && fdsDelta > 2) grows.push(`file descriptors +${fdsDelta}`);
    if (watchesDelta != null && watchesDelta > 0) grows.push(`inotify watches +${watchesDelta}`);
    if (childrenDelta != null && childrenDelta > 0) grows.push(`children +${childrenDelta}`);
    if (maxLongTaskMs != null && maxLongTaskMs > budget.longTaskMsCycles) grows.push(`a ${maxLongTaskMs} ms main-thread task (budget ${budget.longTaskMsCycles} ms)`);
    if (notResponding > 0) grows.push(`${notResponding} not-responding dialog${notResponding === 1 ? '' : 's'}`);
    return grows.length
      ? { ...base, verdict: 'grows', why: `unjudged — measured against §5 here: ${grows.join(' · ')}` }
      : { ...base, verdict: 'holds', why: 'unjudged — measured against §5 here and inside every budget' };
  }
  return { ...base, verdict: 'unknown', why: 'a soak is running — no verdict row yet' };
}

/* ---- the whole reading --------------------------------------------------- */
export interface ReadSoakHealthOptions {
  /** $YMIR_HOME — the soak state lives at `<home>/state/soak`. */
  homeDir: string;
  /** The app registry's names (`bin/desktop/ymir-app --list`). */
  appNames?: string[];
  /** `now`, so a test can pin the clock. */
  now?: number;
  budgets?: SoakBudgets;
}

export function readSoakHealth(opts: ReadSoakHealthOptions): SoakHealth {
  const home = opts.homeDir;
  const budget = opts.budgets ?? BUDGETS;
  const now = opts.now ?? Date.now();
  const state = home ? join(home, 'state', 'soak') : '';

  /** An app with no soak is still a row: it has not been measured, which is a fact. */
  const unsoaked = (names: string[]): AppHealth[] =>
    Array.from(new Set(names)).sort().map((app) => ({
      app, present: false, date: '', samples: 0, windowMinutes: 0,
      rssPct: null, rssStartMb: null, rssNowMb: null, heapMbDelta: null,
      fdsDelta: null, watchesDelta: null, childrenDelta: null, gpuMib: null,
      maxLongTaskMs: null, notResponding: 0, cycles: 0, applied: 'idle',
      verdict: 'unknown', why: `no soak yet — run bin/gates/soak.sh ${app}`,
      sampled: null,
    }));

  const empty: SoakHealth = {
    state, budget, windowMinutes: budget.idleMinutes,
    lastPass: '', ageMinutes: null, passes: 0, stale: false,
    services: [], apps: unsoaked(opts.appNames ?? []), storms: [],
  };
  if (!home || !existsSync(state)) {
    return { ...empty, error: `no soak ledger at ${state || '<home unresolved>'} — the sampler has not run on this machine` };
  }

  try {
    if (!statSync(state).isDirectory()) return { ...empty, error: `${state} is not a directory` };
  } catch (e) {
    return { ...empty, error: `the soak ledger could not be read: ${(e as Error).message}` };
  }

  /* services: read the newest files until the window is covered (or two files) */
  const svcFiles = jsonlFiles(join(state, 'services'));
  const rows: Array<Record<string, unknown>> = [];
  for (let i = svcFiles.length - 1; i >= 0 && svcFiles.length - i <= 2; i--) {
    rows.unshift(...parseJsonl(svcFiles[i]));
  }

  const passRows = rows.filter((r) => str(r.kind) === 'pass');
  const lastPassTs = passRows.length
    ? str(passRows[passRows.length - 1].ts)
    : rows.length ? str(rows[rows.length - 1].ts) : '';
  const lastPassMs = tsMs(lastPassTs);
  const ageMinutes = Number.isFinite(lastPassMs) ? Math.max(0, Math.round((now - lastPassMs) / 60_000)) : null;

  const stormRows = rows.filter((r) => str(r.kind) === 'storm');
  const storms: SoakHealth['storms'] = stormRows.slice(-25).map((r) => ({
    name: str(r.name), ts: str(r.ts), action: str(r.action),
    restarts: num(r.restarts) ?? 0, threshold: num(r.threshold) ?? 0, lastError: str(r.last_error),
  }));

  // The trend is measured over the ledger's OWN last window, so a stopped timer
  // still shows the last true trend instead of an empty one — `stale` says the
  // ledger has not moved since.
  const windowEnd = Number.isFinite(lastPassMs) ? lastPassMs : now;
  const windowStart = windowEnd - budget.idleMinutes * 60_000;

  const newestPass = passRows.length ? str(passRows[passRows.length - 1].pass) : '';
  const newestNames = new Set<string>();
  for (const r of rows) {
    if (str(r.kind) !== 'service') continue;
    // a pass has no id in some older rows: fall back to the last pass's timestamp
    const onNewest = newestPass ? str(r.pass) === newestPass : tsMs(r.ts) === windowEnd;
    if (onNewest) newestNames.add(str(r.name));
  }

  const byName = new Map<string, ServiceRow[]>();
  for (const r of rows) {
    if (str(r.kind) !== 'service') continue;
    const s = serviceRow(r);
    if (!s || !Number.isFinite(tsMs(s.ts))) continue;
    if (tsMs(s.ts) < windowStart || tsMs(s.ts) > windowEnd) continue;
    if (newestNames.size && !newestNames.has(s.name)) continue;
    const list = byName.get(s.name) ?? [];
    list.push(s);
    byName.set(s.name, list);
  }

  const services: ServiceTrend[] = [];
  for (const list of byName.values()) {
    list.sort((a, b) => tsMs(a.ts) - tsMs(b.ts));
    services.push(judgeService(list, storms, budget));
  }
  services.sort((a, b) => {
    const rank = (v: Verdict) => (v === 'restarts' ? 0 : v === 'grows' ? 1 : v === 'unknown' ? 2 : 3);
    return rank(a.verdict) - rank(b.verdict) || a.name.localeCompare(b.name);
  });

  /* apps: the last soak per directory, with the sampler's figures as a hint */
  const appRows = rows.filter((r) => str(r.kind) === 'app' && str(r.pass) === newestPass);
  const sampled = new Map<string, AppHealth['sampled']>();
  for (const r of appRows) {
    const name = str(r.name);
    if (!name) continue;
    sampled.set(name, {
      rssMb: mib(num(r.rss_kb)), fds: num(r.fds),
      watches: num(r.inotify_watches), children: num(r.pids),
      gpuMib: num(r.gpu_mib), state: str(r.state),
    });
  }

  const soakDirs = (() => {
    try {
      return readdirSync(state).filter((d) => {
        if (d === 'services' || d.startsWith('.')) return false;
        try {
          return statSync(join(state, d)).isDirectory();
        } catch {
          return false;
        }
      });
    } catch {
      return [];
    }
  })();
  const appNames = Array.from(new Set([...(opts.appNames ?? []), ...soakDirs])).sort();

  const apps: AppHealth[] = [];
  for (const app of appNames) {
    const dir = join(state, app);
    const files = jsonlFiles(dir);
    if (!files.length) {
      apps.push({
        app, present: false, date: '', samples: 0, windowMinutes: 0,
        rssPct: null, rssStartMb: null, rssNowMb: null, heapMbDelta: null,
        fdsDelta: null, watchesDelta: null, childrenDelta: null, gpuMib: null,
        maxLongTaskMs: null, notResponding: 0, cycles: 0, applied: 'idle',
        verdict: 'unknown', why: 'no soak yet — run bin/gates/soak.sh ' + app,
        sampled: sampled.get(app) ?? null,
      });
      continue;
    }
    const newest = files[files.length - 1];
    const appHealth = judgeApp(app, parseJsonl(newest), budget);
    appHealth.date = appHealth.date || newest.split('/').pop()!.replace('.jsonl', '');
    if (!appHealth.present) appHealth.present = true;
    apps.push(appHealth);
  }
  apps.sort((a, b) => (a.present === b.present ? a.app.localeCompare(b.app) : a.present ? -1 : 1));

  const staleThreshold = budget.sampleIntervalMinutes * 3;
  const stale = ageMinutes != null && ageMinutes > staleThreshold;
  const result: SoakHealth = {
    state, budget,
    windowMinutes: budget.idleMinutes,
    lastPass: lastPassTs, ageMinutes, passes: passRows.length, stale,
    services, apps, storms,
  };
  if (!rows.length) result.error = `the ledger at ${join(state, 'services')} holds no rows`;
  return result;
}

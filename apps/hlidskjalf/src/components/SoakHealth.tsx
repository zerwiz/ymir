import { useCallback, useEffect, useState } from 'react';
import { gateApi, type AppHealth, type ServiceTrend, type SoakHealth, type SoakVerdict } from '../services/api';

/**
 * Health — the leak ledger and every app's last soak, drawn for a PERSON
 * (plan 286 P6, RULES/52).
 *
 * Each row answers one question: is this service or app HOLDING, or does it
 * GROW, or does it RESTART? The verdict is computed in the gate from plan 286
 * §5's budgets (`server/health.ts`), never here; the page only says it plainly
 * and names the number that broke. An app with no soak yet says so — it is not
 * a pass, and it is not a crash.
 */

const VERDICT: Record<SoakVerdict, { label: string; tone: 'ok' | 'warn' | 'danger' | 'none'; glyph: string }> = {
  holds: { label: 'holds', tone: 'ok', glyph: 'ᛟ' },
  grows: { label: 'grows', tone: 'warn', glyph: 'ᛇ' },
  restarts: { label: 'restarts', tone: 'danger', glyph: 'ᛪ' },
  unknown: { label: 'unknown', tone: 'none', glyph: '·' },
};

export function VerdictPill({ verdict }: { verdict: SoakVerdict }) {
  const meta = VERDICT[verdict] ?? VERDICT.unknown;
  if (meta.tone === 'none') {
    return (
      <span className="status" style={{ color: 'var(--ymir-text-2)', whiteSpace: 'nowrap' }}>
        <span className="dot" aria-hidden="true">{meta.glyph}</span>
        {meta.label}
      </span>
    );
  }
  return (
    <span className={`status status-${meta.tone}`} style={{ whiteSpace: 'nowrap' }}>
      <span className="dot" aria-hidden="true">{meta.glyph}</span>
      {meta.label}
    </span>
  );
}

const mb = (v: number | null | undefined): string => (v == null ? '—' : `${v.toFixed(1)} MB`);
const num = (v: number | null | undefined): string => (v == null ? '—' : String(v));
const delta = (v: number | null | undefined): string => (v == null ? '—' : v > 0 ? `+${v}` : String(v));
const pct = (v: number | null | undefined): string => (v == null ? '—' : `${v > 0 ? '+' : ''}${v} %`);
const gpu = (v: number | null | undefined): string => (v == null ? 'no GPU' : `${v} MB`);

function age(minutes: number | null): string {
  if (minutes == null) return 'never';
  if (minutes < 1) return 'just now';
  if (minutes < 90) return `${minutes} min ago`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m ? `${h} h ${m} min ago` : `${h} h ago`;
}

/** A duration, not a moment: "for 5 h 57 min", never "for 5 h 57 min ago". */
function span(minutes: number | null): string {
  if (minutes == null) return 'longer than the ledger remembers';
  if (minutes < 1) return 'under a minute';
  if (minutes < 90) return `${minutes} min`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m ? `${h} h ${m} min` : `${h} h`;
}

function counts(rows: SoakVerdict[]): string {
  const c = { holds: 0, grows: 0, restarts: 0, unknown: 0 } as Record<SoakVerdict, number>;
  for (const v of rows) c[v] = (c[v] ?? 0) + 1;
  const parts: string[] = [];
  if (c.grows) parts.push(`${c.grows} grow`);
  if (c.restarts) parts.push(`${c.restarts} restart${c.restarts === 1 ? '' : 's'}`);
  if (c.holds) parts.push(`${c.holds} hold${c.holds === 1 ? '' : 's'}`);
  if (c.unknown) parts.push(`${c.unknown} unjudged`);
  return parts.join(' · ') || 'nothing measured';
}

function ServiceRow({ s }: { s: ServiceTrend }) {
  const warm = s.verdict !== 'holds';
  return (
    <div
      className="row-between"
      style={{ padding: '8px 12px', borderBottom: '1px solid var(--ymir-steel-1)', gap: 10, alignItems: 'flex-start' }}
    >
      <span className="col" style={{ gap: 2, minWidth: 0, flex: 1 }}>
        <span className="mono" style={{ fontSize: 12, overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {s.name.replace(/\.service$/, '')}
        </span>
        <span className="dim" style={{ fontSize: 11, color: warm ? 'var(--ymir-text-1)' : 'var(--ymir-text-2)' }}>
          {s.why}
        </span>
      </span>
      <span className="col" style={{ gap: 2, alignItems: 'flex-end', minWidth: 190, textAlign: 'right' }}>
        <span className="mono" style={{ fontSize: 11 }}>
          {mb(s.rssNowMb)} <span className="dim">{pct(s.rssPct)}</span>
        </span>
        <span className="mono dim" style={{ fontSize: 10 }}>
          fds {num(s.fdsNow)} ({delta(s.fdsDelta)}) · watches {num(s.watchesNow)} ({delta(s.watchesDelta)}) · children{' '}
          {num(s.childrenNow)} ({delta(s.childrenDelta)})
        </span>
        <span className="mono dim" style={{ fontSize: 10 }}>
          GPU {gpu(s.gpuMib)} · restarts {s.restarts}
          {s.restartsInWindow ? ` (+${s.restartsInWindow} in ${s.windowMinutes} min)` : ''}
        </span>
      </span>
      <span style={{ minWidth: 92, textAlign: 'right' }}>
        <VerdictPill verdict={s.verdict} />
      </span>
    </div>
  );
}

function AppRow({ a }: { a: AppHealth }) {
  let detail: string;
  if (a.present) {
    detail = [
      `${a.samples} samples over ${a.windowMinutes} min`,
      `RSS ${mb(a.rssStartMb)} → ${mb(a.rssNowMb)}${a.applied === 'cycles' ? ' after the cycles' : ' while idle'} (${pct(a.rssPct)})`,
      a.heapMbDelta != null ? `heap ${delta(a.heapMbDelta)} MB` : '',
      a.fdsDelta != null ? `fds ${delta(a.fdsDelta)}` : '',
      a.watchesDelta != null ? `watches ${delta(a.watchesDelta)}` : '',
      a.childrenDelta != null ? `children ${delta(a.childrenDelta)}` : '',
      a.maxLongTaskMs != null ? `longest task ${a.maxLongTaskMs} ms` : '',
      a.notResponding ? `${a.notResponding} not-responding` : '',
      `GPU ${gpu(a.gpuMib)}`,
    ]
      .filter(Boolean)
      .join(' · ');
  } else if (a.sampled) {
    detail = `the sampler last saw it ${a.sampled.state || 'running'} at ${mb(a.sampled.rssMb)}, ${num(a.sampled.fds)} fds, ${num(a.sampled.watches)} watches, ${num(a.sampled.children)} children`;
  } else {
    detail = 'the sampler has not seen it either';
  }
  return (
    <div
      className="row-between"
      style={{ padding: '8px 12px', borderBottom: '1px solid var(--ymir-steel-1)', gap: 10, alignItems: 'flex-start' }}
    >
      <span className="col" style={{ gap: 2, minWidth: 0, flex: 1 }}>
        <span className="mono" style={{ fontSize: 12 }}>{a.app}</span>
        <span className="dim" style={{ fontSize: 11, color: 'var(--ymir-text-2)' }}>
          {a.present ? `${a.why} — ${detail}` : `${a.why} · ${detail}`}
        </span>
      </span>
      <span style={{ minWidth: 92, textAlign: 'right' }}>
        <VerdictPill verdict={a.verdict} />
      </span>
    </div>
  );
}

export function SoakHealthPanel() {
  const [data, setData] = useState<SoakHealth | null>(null);
  const [error, setError] = useState('');
  const [open, setOpen] = useState(false);

  const load = useCallback(async () => {
    try {
      setData(await gateApi.soak());
      setError('');
    } catch (e) {
      setError((e as Error).message);
    }
  }, []);

  useEffect(() => {
    void load();
    const id = window.setInterval(() => void load(), 30_000);
    return () => window.clearInterval(id);
  }, [load]);

  const budget = data?.budget;
  const services = data?.services ?? [];
  const apps = data?.apps ?? [];
  const serviceVerdicts = services.map((s) => s.verdict);
  const appVerdicts = apps.filter((a) => a.present).map((a) => a.verdict);

  return (
    <>
      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛉ</span> Health — every service and app, measured
          </div>
          <div className="row" style={{ gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
            {data ? (
              <span className="mono dim" style={{ fontSize: 10 }}>
                last pass {age(data.ageMinutes)} · {data.passes} passes
              </span>
            ) : null}
            <button className="btn btn-sm" aria-expanded={open} onClick={() => setOpen((v) => !v)}>
              <span aria-hidden="true">{open ? '▾' : '▸'}</span> {open ? 'hide the budgets' : 'the budgets'}
            </button>
          </div>
        </div>

        {open && budget ? (
          <div className="panel-body col" style={{ gap: 4, borderBottom: '1px solid var(--ymir-steel-1)', fontSize: 12 }}>
            <span className="realm-scope-label">plan 286 §5 — first numbers, to be approved</span>
            <span className="muted">
              At idle over {budget.idleMinutes} min: RSS growth under {budget.rssPctIdle} %, file descriptors flat,
              inotify watches flat, children flat and no zombie, no main-thread task over {budget.longTaskMsIdle} ms,
              no not-responding dialog, a service under {budget.restartsPerHour} restarts an hour. After 20 open-and-close
              cycles: RSS under {budget.rssPctCycles} %, JS heap under {budget.heapMbCycles} MB, nothing over{' '}
              {budget.longTaskMsCycles} ms.
            </span>
          </div>
        ) : null}

        {error ? (
          <div className="panel-body">
            <p className="muted">The leak ledger could not be read: {error}</p>
          </div>
        ) : !data ? (
          <div className="panel-body">
            <p className="muted">Reading the leak ledger…</p>
          </div>
        ) : (
          <>
            {data.stale ? (
              <div className="panel-body" style={{ borderBottom: '1px solid var(--ymir-steel-1)' }}>
                <p className="muted" style={{ fontSize: 12, color: 'var(--ymir-warn)' }}>
                  The ledger has not moved for {span(data.ageMinutes)}: the sampler writes every{' '}
                  {budget?.sampleIntervalMinutes ?? 5} min, so the timer is likely stopped on this machine. The trend
                  below is the ledger's own last {data.windowMinutes} min, not the last {data.windowMinutes} min of today.
                </p>
              </div>
            ) : null}
            {data.error ? (
              <div className="panel-body">
                <p className="muted" style={{ fontSize: 12 }}>{data.error}</p>
              </div>
            ) : null}
            <div className="panel-body">
              <p className="muted" style={{ fontSize: 11 }}>
                Rows are the leak ledger's own samples (<span className="mono">{data.state || 'state/soak'}</span>); an
                app's soak lives in <span className="mono">state/soak/&lt;app&gt;/</span> and is written by{' '}
                <span className="mono">bin/gates/soak.sh</span>.
              </p>
            </div>
          </>
        )}
      </section>

      {data ? (
        <>
          <section className="panel">
            <div className="panel-head">
              <div className="panel-title">
                <span className="glyph" aria-hidden="true">ᚱ</span> Services
              </div>
              <span className="mono dim" style={{ fontSize: 10 }}>
                {services.length} on this machine · {counts(serviceVerdicts)}
              </span>
            </div>
            <div className="panel-body flush" style={{ maxHeight: 380, overflowY: 'auto' }}>
              {services.length === 0 ? (
                <p className="muted" style={{ padding: 12 }}>No service rows in the ledger's last window.</p>
              ) : (
                services.map((s) => <ServiceRow key={s.name} s={s} />)
              )}
            </div>
          </section>

          <section className="panel">
            <div className="panel-head">
              <div className="panel-title">
                <span className="glyph" aria-hidden="true">ᛇ</span> Apps — their last soak
              </div>
              <span className="mono dim" style={{ fontSize: 10 }}>
                {apps.filter((a) => a.present).length} soaked · {apps.filter((a) => !a.present).length} waiting ·{' '}
                {counts(appVerdicts)}
              </span>
            </div>
            <div className="panel-body flush" style={{ maxHeight: 320, overflowY: 'auto' }}>
              {apps.length === 0 ? (
                <p className="muted" style={{ padding: 12 }}>No app registry could be read.</p>
              ) : (
                apps.map((a) => <AppRow key={a.app} a={a} />)
              )}
            </div>
          </section>

          {data.storms.length ? (
            <section className="panel">
              <div className="panel-head">
                <div className="panel-title">
                  <span className="glyph" aria-hidden="true">ᛪ</span> Stopped by the restart ward
                </div>
                <span className="mono dim" style={{ fontSize: 10 }}>{data.storms.length} recent</span>
              </div>
              <div className="panel-body flush" style={{ maxHeight: 200, overflowY: 'auto' }}>
                {data.storms.map((s) => (
                  <div key={`${s.name}-${s.ts}`} className="row-between" style={{ padding: '6px 12px', borderBottom: '1px solid var(--ymir-steel-1)', fontSize: 12 }}>
                    <span className="col" style={{ gap: 1, minWidth: 0 }}>
                      <span className="mono">{s.name.replace(/\.service$/, '')}</span>
                      <span className="dim" style={{ fontSize: 11 }}>{s.lastError || s.action}</span>
                    </span>
                    <span className="mono dim" style={{ fontSize: 10 }}>
                      {s.restarts} restarts · limit {s.threshold}/h · {s.ts.slice(11, 16)}Z
                    </span>
                  </div>
                ))}
              </div>
            </section>
          ) : null}
        </>
      ) : null}
    </>
  );
}

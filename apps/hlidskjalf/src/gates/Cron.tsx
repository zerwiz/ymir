import { useEffect, useState } from 'react';
import { gateApi, type NornirState, type NornirStatus } from '../services/api';
import { useYmir } from '../state/store';
import { StatusChip } from '../components/Status';
import { MetricTile } from '../components/MetricTile';

// The house tones (Hlidskjalf tokens) and marks (the same glyphs as bin/desktop/ymir-style.sh): green is
// RAN/ELSEWHERE/MOVED, quiet is DUE/IDLE, and only LATE, FAILED, DOWN and DARK are red.
const NORNIR_TONE: Record<NornirState, string> = {
  RAN: 'var(--ymir-ok)', ELSEWHERE: 'var(--ymir-ok)', MOVED: 'var(--ymir-warn)', DUE: 'var(--ymir-info)', IDLE: 'var(--ymir-muted)', UNREAD: 'var(--ymir-warn)',
  LATE: 'var(--ymir-danger)', FAILED: 'var(--ymir-danger)', DOWN: 'var(--ymir-danger)', DARK: 'var(--ymir-danger)',
};
const NORNIR_MARK: Record<NornirState, string> = {
  RAN: '✓', ELSEWHERE: '✓', MOVED: '✓', DUE: '—', IDLE: '·', UNREAD: '?', LATE: '✕', FAILED: '✕', DOWN: '✕', DARK: '✕',
};

/**
 * Cron — the Nornir schedule, both faces (plan 54, 2026-09-24). The LOCAL seat's
 * loop and the SERVER seats' are read from `/api/cron`
 * and `/api/cron/seats`; the schedule is the file the loop itself reads
 * (`$YMIR_HOME/config/cron.yaml`), so the picture cannot drift from the runtime.
 * A stopped loop says WHY; a seat that cannot be reached says so. Read-only.
 */
export function Cron() {
  const cron = useYmir((s) => s.cron);
  const seats = useYmir((s) => s.cronSeats) ?? [];
  const cronError = useYmir((s) => s.cronError);
  const startCron = useYmir((s) => s.startCron);
  const stopCron = useYmir((s) => s.stopCron);
  const [busy, setBusy] = useState(false);
  // Every job judged on the seat that OWNS it (plan 365): one resolver, shared with `ymir nornir` and Eir.
  const [nornir, setNornir] = useState<NornirStatus | null>(null);
  useEffect(() => {
    let live = true;
    const read = () => { gateApi.cronStatus().then((v) => { if (live) setNornir(v); }).catch(() => {}); };
    read();
    const t = setInterval(read, 60000);
    return () => { live = false; clearInterval(t); };
  }, []);
  const verdict = (cmd: string, at: string) => nornir?.jobs.find((x) => x.cmd === cmd && x.at === at);
  const jobs = cron?.jobs ?? [];
  const running = cron?.running ?? false;
  const roles = cron?.roles ?? [];
  const applies = jobs.filter((j) => j.applies).length;
  const reachable = seats.filter((s) => s.reachable && s.running).length;

  const sourceNote =
    cron?.source === 'home' ? 'live · $YMIR_HOME/config/cron.yaml'
      : cron?.source === 'repo' ? 'live · repo config/cron.yaml'
        : cron?.source === 'example' ? 'the shipped EXAMPLE — this home has no config/cron.yaml yet'
          : cron ? 'no schedule file found' : 'offline';

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Nornir · Cron</h1>
          <p className="stage-deck">
            The fates who govern time · local and server schedules, started at session open
          </p>
        </div>
        <div className="row">
          <StatusChip status={running ? 'nominal' : 'down'} />
          {running ? (
            <button
              className="btn btn-sm"
              disabled={busy}
              onClick={() => {
                setBusy(true);
                void stopCron().finally(() => setBusy(false));
              }}
              title="Lower this seat's scheduler (bin/time/nornir-cron-start.sh --stop)"
            >
              {busy ? '…' : 'Stop'}
            </button>
          ) : (
            <button
              className="btn btn-primary btn-sm"
              disabled={busy}
              onClick={() => {
                setBusy(true);
                void startCron().finally(() => setBusy(false));
              }}
              title="Raise this seat's scheduler (bin/time/nornir-cron-start.sh)"
            >
              {busy ? '…' : 'Start'}
            </button>
          )}
        </div>
      </div>

      {cronError ? (
        <div className="panel" style={{ marginBottom: 'var(--ymir-space-4)' }}>
          <div className="panel-body">
            <p style={{ margin: 0 }} className="muted">
              The board could not read the schedule — {cronError}. The numbers below are an
              <strong> unread </strong> schedule, not a stopped one.
            </p>
          </div>
        </div>
      ) : null}

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile
          label="Local scheduler"
          value={running ? 'RUNNING' : 'STOPPED'}
          tone={running ? 'var(--ymir-ok)' : 'var(--ymir-danger)'}
          delta={cron?.pid ? `pid ${cron.pid}` : cron?.why || '—'}
        />
        <MetricTile label="Jobs declared" value={jobs.length} delta={sourceNote} />
        <MetricTile
          label="Needs you"
          value={nornir ? nornir.needs : '…'}
          tone={nornir && nornir.needs > 0 ? 'var(--ymir-danger)' : 'var(--ymir-ok)'}
          delta={nornir ? (Object.entries(nornir.counts).map(([k, v]) => `${v} ${k.toLowerCase()}`).join(' · ') || '—')
            : `role: ${roles.length ? roles.join(', ') : 'none — ungated jobs only'} · ${applies}/${jobs.length} here`}
        />
        <MetricTile
          label="Servers up"
          value={`${reachable}/${seats.length}`}
          delta={seats.length
            ? seats.map((s) => (s.reachable && s.running ? s.seat : `${s.seat} ${s.reachable ? '(scheduler stopped)' : '(unreachable)'}`)).join(' · ')
            : '—'}
        />
      </div>

      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛃ</span>
            Local · this seat
          </div>
          <span className="mono dim" style={{ fontSize: 10 }}>{sourceNote}</span>
        </div>
        <div className="panel-body flush">
          {!running && cron?.why ? (
            <div className="muted" style={{ padding: '8px 12px', fontSize: 12 }}>
              stopped — {cron.why}
            </div>
          ) : null}
          <table className="data-table">
            <thead>
              <tr>
                <th>Time</th>
                <th>Job</th>
                <th>Role</th>
                <th>Where it stands</th>
                <th>Last</th>
              </tr>
            </thead>
            <tbody>
              {jobs.map((j) => (
                <tr key={j.at + j.role + j.command}>
                  <td className="mono num" style={{ whiteSpace: 'nowrap' }}>{j.at}</td>
                  <td className="mono">{j.command}</td>
                  <td className="mono" style={{ whiteSpace: 'nowrap' }}>{j.role ? `@${j.role}` : 'any'}</td>
                  <td>
                    {(() => {
                      const v = verdict(j.command, j.at);
                      if (!v) return <span className="muted">{nornir ? '—' : 'reading…'}</span>;
                      return (
                        <span title={v.next || v.detail} style={{ color: NORNIR_TONE[v.status] }}>
                          <strong>{NORNIR_MARK[v.status]} {v.status}</strong> <span className="dim">{v.detail}</span>
                          {v.next ? <div className="dim" style={{ fontSize: 11 }}>→ {v.next}</div> : null}
                        </span>
                      );
                    })()}
                  </td>
                  <td className="mono dim">{cron?.last?.[j.command] ?? '—'}</td>
                </tr>
              ))}
              {jobs.length === 0 ? (
                <tr>
                  <td colSpan={5} className="muted" style={{ padding: 12 }}>
                    {cron?.source === 'example'
                      ? 'No schedule of your own — copy config/cron.yaml.example to $YMIR_HOME/config/cron.yaml.'
                      : 'No schedule file found (config/cron.yaml is absent).'}
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>

      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᚨ</span>
            Servers · the fleet's crons
          </div>
          <span className="mono dim" style={{ fontSize: 10 }}>live over the ssh ring · each seat answers for itself</span>
        </div>
        <div className="panel-body flush">
          <table className="data-table">
            <thead>
              <tr>
                <th>Seat</th>
                <th>Reachable</th>
                <th>Scheduler</th>
                <th>Role</th>
                <th>Runs</th>
              </tr>
            </thead>
            <tbody>
              {seats.map((s) => (
                <tr key={s.seat}>
                  <td className="mono" style={{ whiteSpace: 'nowrap' }}>{s.seat}</td>
                  <td>
                    <StatusChip status={s.reachable ? 'nominal' : 'down'} />
                  </td>
                  <td className="mono">
                    {s.reachable ? (s.running ? `running · pid ${s.pid}` : 'stopped') : s.error ?? 'unreachable'}
                  </td>
                  <td className="mono">{s.roles.length ? s.roles.join(', ') : '—'}</td>
                  <td className="mono num">{s.reachable ? `${s.applies}/${s.jobs}` : '—'}</td>
                </tr>
              ))}
              {seats.length === 0 ? (
                <tr>
                  <td colSpan={5} className="muted" style={{ padding: 12 }}>
                    No server seats read yet — the gate API answers /api/cron/seats over the ssh ring.
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

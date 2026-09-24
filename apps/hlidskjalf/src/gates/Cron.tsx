import { useYmir } from '../state/store';
import { StatusChip } from '../components/Status';
import { MetricTile } from '../components/MetricTile';

/**
 * Cron — the Nornir schedule, both faces (plan 54, 2026-09-24). The LOCAL seat's
 * loop and the SERVER seats' (whynot · zerwizserver) are read from `/api/cron`
 * and `/api/cron/seats`; the schedule is the file the loop itself reads
 * (`$YMIR_HOME/config/cron.yaml`), so the picture cannot drift from the runtime.
 * A stopped loop says WHY; a seat that cannot be reached says so. Read-only.
 */
export function Cron() {
  const cron = useYmir((s) => s.cron);
  const seats = useYmir((s) => s.cronSeats) ?? [];
  const jobs = cron?.jobs ?? [];
  const running = cron?.running ?? false;
  const roles = cron?.roles ?? [];
  const applies = jobs.filter((j) => j.applies).length;
  const reachable = seats.filter((s) => s.reachable).length;

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
        </div>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile
          label="Local scheduler"
          value={running ? 'RUNNING' : 'STOPPED'}
          tone={running ? 'var(--ymir-ok)' : 'var(--ymir-danger)'}
          delta={cron?.pid ? `pid ${cron.pid}` : cron?.why || '—'}
        />
        <MetricTile label="Jobs declared" value={jobs.length} delta={sourceNote} />
        <MetricTile
          label="Runs on this seat"
          value={`${applies}/${jobs.length}`}
          delta={`role: ${roles.length ? roles.join(', ') : 'none — ungated jobs only'}`}
        />
        <MetricTile
          label="Servers up"
          value={`${reachable}/${seats.length}`}
          delta={seats.length ? seats.map((s) => s.seat).join(' · ') : '—'}
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
                <th>Runs here</th>
                <th>Last</th>
              </tr>
            </thead>
            <tbody>
              {jobs.map((j) => (
                <tr key={j.at + j.role + j.command}>
                  <td className="mono num">{j.at}</td>
                  <td className="mono">{j.command}</td>
                  <td className="mono">{j.role ? `@${j.role}` : 'any'}</td>
                  <td>
                    <StatusChip status={j.applies ? 'nominal' : 'down'} />
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
          <span className="mono dim" style={{ fontSize: 10 }}>live over the ssh ring · whynot · zerwizserver</span>
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
                  <td className="mono">{s.seat}</td>
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

import { useYmir } from '../state/store';
import { StatusChip } from '../components/Status';
import { MetricTile } from '../components/MetricTile';

/**
 * Cron — the Nornir schedule (plan 24). Live mode reads `/api/cron`; demo mode
 * shows no jobs. Read-only.
 */
export function Cron() {
  const cron = useYmir((s) => s.cron);
  const jobs = cron?.jobs ?? [];
  const running = cron?.running ?? false;

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Nornir · Cron</h1>
          <p className="stage-deck">
            The fates who govern time · scheduled jobs, started at session open
          </p>
        </div>
        <div className="row">
          <StatusChip status={running ? 'nominal' : 'down'} />
        </div>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Scheduler" value={running ? 'RUNNING' : 'STOPPED'} tone={running ? 'var(--ymir-ok)' : 'var(--ymir-danger)'} delta={cron?.pid ? `pid ${cron.pid}` : '—'} spark={[jobs.length, jobs.length, jobs.length]} />
        <MetricTile label="Jobs" value={jobs.length} delta="declared in config/cron.yaml" spark={[1, 2, 3, jobs.length]} />
        <MetricTile label="Daily briefing" value="07:00" delta="workspace/memory/daily" spark={[1, 1, 1]} />
        <MetricTile label="Observer" value="06:00" delta="Huginn · read-only" spark={[1, 1, 1]} />
      </div>

      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛃ</span>
            Schedule
          </div>
          <span className="mono dim" style={{ fontSize: 10 }}>
            {cron ? 'live · nornir-cron-start.sh' : 'demo / offline'}
          </span>
        </div>
        <div className="panel-body flush">
          <table className="data-table">
            <thead>
              <tr>
                <th>Time</th>
                <th>Job</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {jobs.map((j) => (
                <tr key={j.at + j.command}>
                  <td className="mono num">{j.at}</td>
                  <td className="mono">{j.command}</td>
                  <td>
                    <StatusChip status={j.status === 'scheduled' ? 'nominal' : 'down'} />
                  </td>
                </tr>
              ))}
              {jobs.length === 0 ? (
                <tr>
                  <td colSpan={3} className="muted" style={{ padding: 12 }}>
                    No jobs. Sign in live (gate API) to read config/cron.yaml.
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

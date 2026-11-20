import { useYmir } from '../state/store';
import { StatusChip } from '../components/Status';
import { MetricTile } from '../components/MetricTile';
import { VISUALIZER_URL } from '../data/metadata';

function tone(status: string | null) {
  return status === 'success' ? 'nominal' : status === 'fail' ? 'down' : 'degraded';
}

/** Sessions — every Smiðja factory run, from the repo's own smidja.db (W0080). */
export function Sessions() {
  const rows = useYmir((s) => s.smidjaSessions);
  const db = useYmir((s) => s.smidjaDb);
  const live = useYmir((s) => s.live);
  const setGate = useYmir((s) => s.setGate);
  const select = useYmir((s) => s.setSelectedSession);
  const load = useYmir((s) => s.loadSessionDetail);

  function open(id: string) {
    select(id);
    void load(id);
    setGate('trace');
  }

  const runs = rows.length;
  const ok = rows.filter((r) => r.status === 'success').length;
  const fail = rows.filter((r) => r.status === 'fail').length;
  const tokens = rows.reduce((a, r) => a + (r.total_tokens ?? 0), 0);

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Sessions · Smiðja</h1>
          <p className="stage-deck">Factory runs · phase progress · tokens &amp; cost · smidja.db ({db})</p>
        </div>
        <div className="row">
          <button className="btn" onClick={() => void useYmir.getState().refreshSmidja()} title="Re-read smidja.db">
            <span aria-hidden="true">⟳</span> Refresh
          </button>
          <a className="btn btn-primary" href={VISUALIZER_URL} target="_blank" rel="noreferrer">
            <span aria-hidden="true">ᛋ</span> Open visualizer
          </a>
          <StatusChip status={db === 'present' ? 'nominal' : live === false ? 'degraded' : 'down'} />
        </div>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Runs" value={runs} delta={`${ok} success`} />
        <MetricTile label="Failed" value={fail} tone="var(--ymir-danger)" delta="see Decisions" />
        <MetricTile label="Tokens" value={tokens.toLocaleString()} delta="billed total" />
        <MetricTile label="Source" value="smidja.db" delta="repo-local" />
      </div>

      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛋ</span>
            Runs
          </div>
        </div>
        <div className="panel-body flush">
          {rows.length === 0 ? (
            <div className="empty" style={{ padding: 24 }}>
              <span className="glyph" aria-hidden="true">ᛋ</span>
              <p>
                No runs in <span className="mono">smidja/smidja_data/smidja.db</span>. Run a Smiðja chain to
                write a trace; the view fills itself.
              </p>
            </div>
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Run</th>
                  <th>Factory</th>
                  <th>Allfather</th>
                  <th>Status</th>
                  <th>Tokens</th>
                  <th>Cost</th>
                  <th>Started</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr
                    key={r.smidja_id}
                    onClick={() => open(r.smidja_id)}
                    style={{ cursor: 'pointer' }}
                  >
                    <td className="mono">{r.smidja_id.slice(0, 12)}</td>
                    <td className="mono">{r.smidja_name ?? '—'}</td>
                    <td className="muted">{r.engineer ?? '—'}</td>
                    <td>
                      <StatusChip status={tone(r.status)} />
                    </td>
                    <td className="num">{(r.total_tokens ?? 0).toLocaleString()}</td>
                    <td className="num">${(r.total_cost ?? 0).toFixed(3)}</td>
                    <td className="mono dim">{r.started_at?.slice(0, 19).replace('T', ' ') ?? '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </section>
    </>
  );
}

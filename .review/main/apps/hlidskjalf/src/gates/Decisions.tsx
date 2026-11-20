import { useYmir } from '../state/store';
import { MetricTile } from '../components/MetricTile';

/** Decisions — failures grouped by phase and model, with the fix to apply (W0083). */
export function Decisions() {
  const decisions = useYmir((s) => s.smidjaDecisions);
  const db = useYmir((s) => s.smidjaDb);
  const total = decisions.reduce((a, d) => a + d.count, 0);

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Decisions</h1>
          <p className="stage-deck">The self-improving surface · failures grouped · the fix to apply</p>
        </div>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Failed phases" value={total} tone={total ? 'var(--ymir-danger)' : 'var(--ymir-ok)'} delta="across runs" />
        <MetricTile label="Buckets" value={decisions.length} delta="diagnosis × model" />
        <MetricTile label="Source" value="smidja.db" delta={db} />
        <MetricTile label="Bias" value="fix first" tone="var(--ymir-cyan-1)" delta="action over analysis" />
      </div>

      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᚦ</span>
            Failures
          </div>
        </div>
        <div className="panel-body flush">
          {decisions.length === 0 ? (
            <div className="empty" style={{ padding: 24 }}>
              <span className="glyph" aria-hidden="true">ᚦ</span>
              <p>No failed phases recorded. The forge holds.</p>
            </div>
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Phase</th>
                  <th>Model</th>
                  <th>Count</th>
                  <th>Error</th>
                </tr>
              </thead>
              <tbody>
                {decisions.map((d, i) => (
                  <tr key={`${d.phase}-${d.model}-${i}`}>
                    <td className="mono">{d.phase}</td>
                    <td className="muted">{d.model ?? '—'}</td>
                    <td className="num">{d.count}</td>
                    <td className="mono dim" style={{ maxWidth: 360, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {d.error ?? ''}
                    </td>
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

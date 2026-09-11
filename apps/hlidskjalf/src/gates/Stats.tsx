import { useYmir } from '../state/store';
import { MetricTile } from '../components/MetricTile';

/** Stats — runs, tokens, cost; by chain and model (W0084). */
export function Stats() {
  const stats = useYmir((s) => s.smidjaStats);
  const totals = stats?.totals ?? {};
  const chains = stats?.by_chain ?? [];
  const models = stats?.by_model ?? [];

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Stats</h1>
          <p className="stage-deck">Where the tokens and dollars went · by chain and model</p>
        </div>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Runs" value={totals.runs ?? 0} delta="recorded" />
        <MetricTile label="Tokens" value={(totals.tokens ?? 0).toLocaleString()} delta="billed total" />
        <MetricTile label="Cost" value={`$${(totals.cost ?? 0).toFixed(3)}`} tone="var(--ymir-warn)" delta="summed" />
        <MetricTile label="Chains" value={chains.length} delta="distinct factories" />
      </div>

      <div className="gate-grid cols-2">
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛗ</span>
              By chain
            </div>
          </div>
          <div className="panel-body flush">
            {chains.length === 0 ? (
              <div className="muted" style={{ padding: 12 }}>No runs yet.</div>
            ) : (
              <table className="data-table">
                <thead>
                  <tr><th>Chain</th><th>Runs</th><th>Tokens</th><th>Cost</th></tr>
                </thead>
                <tbody>
                  {chains.map((c) => (
                    <tr key={c.chain}>
                      <td className="mono">{c.chain}</td>
                      <td className="num">{c.runs}</td>
                      <td className="num">{(c.tokens ?? 0).toLocaleString()}</td>
                      <td className="num">${(c.cost ?? 0).toFixed(3)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᚦ</span>
              By model
            </div>
          </div>
          <div className="panel-body flush">
            {models.length === 0 ? (
              <div className="muted" style={{ padding: 12 }}>No agent sessions yet.</div>
            ) : (
              <table className="data-table">
                <thead>
                  <tr><th>Model</th><th>Runs</th><th>Context tokens</th></tr>
                </thead>
                <tbody>
                  {models.map((m) => (
                    <tr key={m.model}>
                      <td className="mono">{m.model}</td>
                      <td className="num">{m.runs}</td>
                      <td className="num">{(m.context_tokens ?? 0).toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </section>
      </div>
    </>
  );
}

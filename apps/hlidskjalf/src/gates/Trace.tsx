import { useYmir } from '../state/store';
import { StatusChip } from '../components/Status';

function tone(status: string | null) {
  return status === 'success' ? 'nominal' : status === 'fail' ? 'down' : status === 'running' ? 'degraded' : 'degraded';
}

/** Trace — one run's lanes, phases, agents, and tool calls (W0081/W0082). */
export function Trace() {
  const id = useYmir((s) => s.selectedSession);
  const detail = useYmir((s) => s.sessionDetail);
  const setGate = useYmir((s) => s.setGate);

  if (!id) {
    return (
      <>
        <div className="stage-head">
          <div>
            <h1 className="stage-title">Trace</h1>
            <p className="stage-deck">Pick a run from Sessions to open its trace.</p>
          </div>
        </div>
        <section className="panel">
          <div className="panel-body">
            <button className="btn" onClick={() => setGate('sessions')}>
              <span aria-hidden="true">ᛋ</span> Open Sessions
            </button>
          </div>
        </section>
      </>
    );
  }

  const phases = detail?.phases ?? [];
  const agents = detail?.agents ?? [];
  const events = detail?.events ?? [];
  const toolCalls = events.filter((e) => e.type === 'tool_call');

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">
            Trace · <span className="mono">{id.slice(0, 12)}</span>
          </h1>
          <p className="stage-deck">
            {detail?.session.smidja_name ?? 'run'} · {phases.length} phases · {agents.length} agents ·{' '}
            {toolCalls.length} tool calls
          </p>
        </div>
        <div className="row">
          <button className="btn" onClick={() => setGate('sessions')}>
            ← Sessions
          </button>
          <StatusChip status={tone(detail?.session.status ?? null)} />
        </div>
      </div>

      <section className="panel" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛚ</span>
            Lanes &amp; phases
          </div>
        </div>
        <div className="panel-body flush">
          {phases.length === 0 ? (
            <div className="muted" style={{ padding: 12 }}>No phases recorded.</div>
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Phase</th>
                  <th>Kind</th>
                  <th>Owner</th>
                  <th>Status</th>
                  <th>Try</th>
                  <th>Error</th>
                </tr>
              </thead>
              <tbody>
                {phases.map((p) => (
                  <tr key={p.phase_id}>
                    <td className="num">{p.seq ?? '—'}</td>
                    <td>
                      <div className="mono">{p.name ?? '—'}</div>
                      {p.description ? <div className="dim" style={{ fontSize: 11 }}>{p.description}</div> : null}
                    </td>
                    <td className="muted">{p.kind ?? '—'}</td>
                    <td className="mono">{p.owner ?? '—'}</td>
                    <td>
                      <StatusChip status={tone(p.status)} />
                    </td>
                    <td className="num">{p.attempt ?? 0}</td>
                    <td className="mono dim" style={{ maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {p.error ?? ''}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </section>

      <div className="gate-grid cols-2">
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᚠ</span>
              Agents &amp; context
            </div>
          </div>
          <div className="panel-body col" style={{ gap: 8 }}>
            {agents.map((a) => (
              <div key={a.agent} className="row-between" style={{ fontSize: 13 }}>
                <span className="mono">{a.agent}</span>
                <span className="muted">{a.model ?? '—'}</span>
                <span className="num">
                  {a.context_tokens != null && a.context_window
                    ? `${Math.round((a.context_tokens / a.context_window) * 100)}%`
                    : '—'}
                </span>
              </div>
            ))}
            {agents.length === 0 ? <span className="muted">No agent sessions.</span> : null}
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛋ</span>
              Tool calls
            </div>
          </div>
          <div className="panel-body flush" style={{ maxHeight: 320, overflow: 'auto' }}>
            {toolCalls.slice(0, 60).map((e) => (
              <div className="trace-row" key={e.rowid} style={{ gridTemplateColumns: 'auto 1fr auto' }}>
                <span className="mono dim">{e.phase_id?.slice(0, 6) ?? '—'}</span>
                <span className="event truncate mono">{e.name ?? e.type}</span>
                <span className="checksum">{e.tokens ?? ''}</span>
              </div>
            ))}
            {toolCalls.length === 0 ? <div className="muted" style={{ padding: 12 }}>No tool calls recorded.</div> : null}
          </div>
        </section>
      </div>
    </>
  );
}

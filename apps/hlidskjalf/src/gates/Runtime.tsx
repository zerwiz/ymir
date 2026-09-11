import { useYmir } from '../state/store';
import { StatusChip } from '../components/Status';

/**
 * Runtime — the Sága session digest as injected at session open (plan 29).
 * Live mode reads `/api/runtime` (bin/saga-session-start.sh); demo mode shows a
 * placeholder. Read-only: the digest is what Brokk received, not an editor.
 */
export function Runtime() {
  const runtime = useYmir((s) => s.runtime);
  const demo = useYmir((s) => s.demo);

  const digest =
    runtime?.digest ||
    (demo
      ? 'BROKK SESSION START — demo mode\n\n(Demo data. Sign in live, or run `bin/saga-session-start.sh`, to see the real digest: lock, Bifrost bridge, wakes, fleet, context, and the Nornir start.)'
      : 'Digest not loaded — start the gate API (`npm run api`) and sign in live.');

  const m = runtime?.markers;

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Runtime</h1>
          <p className="stage-deck">
            Sága, the seeress · the digest injected at session open · {runtime?.doc ?? 'docs/session-start.md'}
          </p>
        </div>
        <div className="row">
          <StatusChip status={runtime ? 'nominal' : demo ? 'degraded' : 'down'} />
        </div>
      </div>

      <div className="gate-grid" style={{ gridTemplateColumns: 'minmax(0, 1fr) 320px' }}>
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛖ</span>
              Session digest
            </div>
            <span className="mono dim" style={{ fontSize: 10 }}>
              {runtime ? 'live · saga-session-start.sh' : demo ? 'demo' : 'offline'}
            </span>
          </div>
          <div className="panel-body flush">
            <pre
              className="mono"
              style={{
                margin: 0,
                padding: 'var(--ymir-space-3)',
                fontSize: 12,
                lineHeight: 1.55,
                whiteSpace: 'pre-wrap',
                color: 'var(--ymir-text-1)',
                overflow: 'auto',
                maxHeight: 460,
              }}
            >
              {digest}
            </pre>
          </div>
        </section>

        <aside className="col" style={{ gap: 'var(--ymir-space-4)' }}>
          <section className="panel">
            <div className="panel-head">
              <div className="panel-title">
                <span className="glyph" aria-hidden="true">ᛜ</span>
                Markers
              </div>
            </div>
            <div className="panel-body col" style={{ gap: 8, fontSize: 13 }}>
              <div className="row-between">
                <span className="muted">lock (Gleipnir)</span>
                <span className="mono">{m?.lock || '—'}</span>
              </div>
              <div className="row-between">
                <span className="muted">started</span>
                <span className="mono" style={{ color: m?.started ? 'var(--ymir-ok)' : 'var(--ymir-warn)' }}>
                  {m?.started ? 'yes' : 'no'}
                </span>
              </div>
              <div className="row-between">
                <span className="muted">armed (Sýn)</span>
                <span className="mono" style={{ color: m?.armed ? 'var(--ymir-ok)' : 'var(--ymir-warn)' }}>
                  {m?.armed ? 'yes' : 'no'}
                </span>
              </div>
            </div>
          </section>

          <section className="panel">
            <div className="panel-head">
              <div className="panel-title">
                <span className="glyph" aria-hidden="true">ᛊ</span>
                The mechanism
              </div>
            </div>
            <div className="panel-body col" style={{ gap: 6, fontSize: 12, color: 'var(--ymir-text-1)' }}>
              <span>Run-tier harnesses execute the digest before the first turn; the result is injected as hidden context.</span>
              <span className="mono dim">docs/session-start.md · docs/lore.md §XII</span>
            </div>
          </section>
        </aside>
      </div>
    </>
  );
}

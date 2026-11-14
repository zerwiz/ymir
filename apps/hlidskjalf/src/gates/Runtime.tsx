import { useEffect, useState } from 'react';
import { useYmir } from '../state/store';
import { StatusChip } from '../components/Status';
import { SoakHealthPanel } from '../components/SoakHealth';

/**
 * Runtime — the house's bearings, drawn for a PERSON (plan 275 items 25 and 27).
 *
 * The page used to print Sága's digest raw: a machine's session context, TOON
 * tables and 163 liveness rows of which ~155 are errands finished days ago
 * (RULES/52 — a person never reads TOON). It now answers four questions in order:
 * who holds the helm, what needs the Allfather, which errands are alive, and which
 * release each service is actually running from. The raw digest is kept whole,
 * behind a fold, because it is the debugging record.
 *
 * The digest is read in the background (it takes ten to fifteen seconds), so the
 * page says it is reading and fills in; the release matrix on the right is live
 * from the first answer.
 */
export function Runtime() {
  const runtime = useYmir((s) => s.runtime);
  const refreshRuntime = useYmir((s) => s.refreshRuntime);
  const [raw, setRaw] = useState(false);

  useEffect(() => {
    if (runtime?.view) return;
    void refreshRuntime();
    const id = window.setInterval(() => void refreshRuntime(), 4000);
    return () => window.clearInterval(id);
  }, [runtime?.view, refreshRuntime]);

  if (!runtime) {
    return (
      <>
        <div className="stage-head">
          <div>
            <h1 className="stage-title">Runtime</h1>
            <p className="stage-deck">Sága, the seeress · the digest injected at session open</p>
          </div>
          <div className="row">
            <StatusChip status="degraded" />
          </div>
        </div>
        <section className="panel">
          <div className="panel-body">
            <p className="muted">
              The gate did not answer yet. Start it with <span className="mono">npm run api</span> in
              <span className="mono"> apps/hlidskjalf</span>, then reload.
            </p>
          </div>
        </section>
      </>
    );
  }

  const { services, mail, markers, digest, view } = runtime;
  const helm = view?.helm;
  const stale = (services.services ?? []).filter((s) => s.running && !s.onPin);

  /** A "needs you" row: the count, and where the door is. */
  const needs = [
    {
      label: 'Decisions waiting',
      value: view ? String(view.decisions) : '—',
      tone: view?.decisions ? 'warn' : 'ok',
    },
    { label: 'New wakes', value: view ? String(view.wakes) : '—', tone: view?.wakes ? 'warn' : 'ok' },
    {
      label: 'Letters that ask for you',
      value: mail.error ? 'desk did not answer' : String(mail.needs),
      tone: mail.needs ? 'warn' : 'ok',
      href: '#/mail',
    },
    { label: 'Open todos', value: view ? String(view.todosOpen) : '—' },
  ] as Array<{ label: string; value: string; tone?: 'warn' | 'ok'; href?: string }>;

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Runtime</h1>
          <p className="stage-deck">Sága, the seeress · the house as this session found it</p>
        </div>
        <div className="row">
          <StatusChip status={!view ? 'degraded' : view.parsed ? 'nominal' : 'degraded'} />
        </div>
      </div>

      {!view ? (
        <section className="panel">
          <div className="panel-body">
            <p className="muted">
              Sága's digest is being read — about twelve seconds the first time. This page fills
              in on its own; the markers and the releases below are already live.
            </p>
          </div>
        </section>
      ) : null}

      {/* 1 · the helm, in one line */}
      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛖ</span> The helm
          </div>
          <span className="mono dim" style={{ fontSize: 10 }}>
            {helm?.holder ? 'this session holds the arm' : view ? 'read-only seat' : 'reading…'}
          </span>
        </div>
        <div className="panel-body" style={{ fontSize: 14, lineHeight: 1.6 }}>
          {helm ? (
            <>
              <strong>{helm.seat || 'unnamed'}</strong> holds it
              {helm.machine ? <> on <span className="mono">{helm.machine}</span></> : null}
              {helm.role ? <> as <span className="mono">{helm.role}</span></> : null}
              {helm.pid ? <> · pid <span className="mono">{helm.pid}</span></> : null}
              {helm.heartbeat ? <> · heartbeat <span className="mono">{helm.heartbeat}</span></> : null}
              {services.pin ? <> · pin <span className="mono">{services.pin}</span></> : null}
              <div className="mono dim" style={{ fontSize: 11, marginTop: 4 }}>
                next step: {view?.next || 'not named'}
              </div>
            </>
          ) : (
            <span className="muted">
              {view ? 'The digest did not name a helm.' : 'Reading the digest…'}
            </span>
          )}
        </div>
      </section>

      {/* 2 · what needs the Allfather */}
      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᚨ</span> What needs you
          </div>
        </div>
        <div className="panel-body metric-grid">
          {needs.map((n) => (
            <div key={n.label} className="metric">
              <span className="muted" style={{ fontSize: 12 }}>{n.label}</span>
              <span
                className="mono"
                style={{
                  fontSize: 20,
                  color: n.tone === 'warn' ? 'var(--ymir-warn)' : n.tone === 'ok' ? 'var(--ymir-ok)' : undefined,
                }}
              >
                {n.value}
              </span>
              {n.href ? (
                <a href={n.href} style={{ fontSize: 11 }}>
                  open the desk →
                </a>
              ) : null}
            </div>
          ))}
        </div>
        {view?.todos.length ? (
          <div className="panel-body col" style={{ gap: 4, borderTop: '1px solid var(--ymir-steel-1)', fontSize: 13 }}>
            <span className="realm-scope-label">due and open</span>
            {view.todos.slice(0, 4).map((t) => (
              <div key={t.id} className="row-between">
                <span>{t.text}</span>
                <span className="mono dim" style={{ fontSize: 11 }}>
                  {t.area}{t.due ? ` · due ${t.due}` : ''}
                </span>
              </div>
            ))}
          </div>
        ) : null}
      </section>

      <div className="gate-grid" style={{ gridTemplateColumns: 'minmax(0, 1fr) 380px' }}>
        {/* 3 · the live errands, by name; finished folded into a count */}
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛏ</span> Errands alive now
            </div>
            <span className="mono dim" style={{ fontSize: 10 }}>
              {view ? `${view.errands.length} alive · ${view.finished} finished` : 'reading…'}
            </span>
          </div>
          <div className="panel-body flush">
            {!view ? (
              <p className="muted" style={{ padding: 'var(--ymir-space-3)' }}>Reading the digest…</p>
            ) : view.errands.length === 0 ? (
              <p className="muted" style={{ padding: 'var(--ymir-space-3)' }}>
                Nothing is running. {view.finished} errands are finished
                {view.unreadable.length ? `, and ${view.unreadable.length} panes could not be read.` : '.'}
              </p>
            ) : (
              view.errands.map((e) => (
                <div key={e.id} className="row-between" style={{ padding: '8px 12px', borderBottom: '1px solid var(--ymir-steel-1)' }}>
                  <span className="col" style={{ gap: 2, minWidth: 0 }}>
                    <strong>{e.id}</strong>
                    <span className="dim" style={{ fontSize: 11 }}>{e.detail}</span>
                  </span>
                  <span className="mono dim" style={{ fontSize: 11 }}>{e.pane}</span>
                </div>
              ))
            )}
          </div>
        </section>

        {/* 4 · which release each service runs from (item 27) */}
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᚱ</span> Releases
            </div>
            <span className="mono" style={{ fontSize: 10, color: stale.length ? 'var(--ymir-warn)' : 'var(--ymir-ok)' }}>
              {services.error ? 'unreadable' : stale.length ? `${stale.length} off the pin` : 'all on the pin'}
            </span>
          </div>
          <div className="panel-body flush" style={{ maxHeight: 320, overflowY: 'auto', fontSize: 12 }}>
            {services.error ? (
              <p className="muted" style={{ padding: 12 }}>{services.error}</p>
            ) : (
              (services.services ?? []).map((s) => (
                <div key={s.unit} className="row-between" style={{ padding: '6px 12px', borderBottom: '1px solid var(--ymir-steel-1)' }}>
                  <span className="col" style={{ gap: 1, minWidth: 0 }}>
                    <span className="mono">{s.unit.replace(/\.service$/, '')}</span>
                    <span className="dim" style={{ fontSize: 10 }}>
                      {s.running ? s.why : `not running (${s.state})`}
                    </span>
                  </span>
                  <span
                    className="mono"
                    style={{
                      fontSize: 10,
                      color: !s.running ? 'var(--ymir-text-2)' : s.onPin ? 'var(--ymir-ok)' : 'var(--ymir-warn)',
                    }}
                  >
                    {s.running ? s.release : '—'}
                  </span>
                </div>
              ))
            )}
          </div>
        </section>
      </div>

      {/* 5 · the leak ledger and every app's last soak (plan 286 P6) */}
      <SoakHealthPanel />

      {/* the record: markers and the raw digest, behind folds */}
      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛜ</span> Markers
          </div>
          <span className="mono dim" style={{ fontSize: 10 }}>{markers.lock || 'no lock'}</span>
        </div>
        <div className="panel-body row" style={{ gap: 'var(--ymir-space-4)', fontSize: 13, flexWrap: 'wrap' }}>
          <span className="muted">
            session started: <span className="mono" style={{ color: markers.started ? 'var(--ymir-ok)' : 'var(--ymir-warn)' }}>{markers.started ? 'yes' : 'no'}</span>
          </span>
          <span className="muted">
            armed: <span className="mono" style={{ color: markers.armed ? 'var(--ymir-ok)' : 'var(--ymir-warn)' }}>{markers.armed ? 'yes' : 'no'}</span>
          </span>
        </div>
      </section>

      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛊ</span> The raw digest
          </div>
          <button className="btn btn-sm" aria-expanded={raw} onClick={() => setRaw((v) => !v)}>
            <span aria-hidden="true">{raw ? '▾' : '▸'}</span> {raw ? 'hide the raw text' : 'show the raw text'}
          </button>
        </div>
        {raw ? (
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
              {digest || 'The digest is still being read, or saga-session-start.sh answered nothing.'}
            </pre>
          </div>
        ) : (
          <div className="panel-body">
            <p className="muted" style={{ fontSize: 12 }}>
              {digest ? `${digest.split('\n').length} lines, written for an agent's context at session open` : 'Not read yet'}
              {runtime.doc ? ` (${runtime.doc})` : ''}. Show it when a section above needs checking
              against the source.
            </p>
          </div>
        )}
      </section>
    </>
  );
}

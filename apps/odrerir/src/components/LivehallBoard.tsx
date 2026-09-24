import { useEffect, useState } from 'react';

/**
 * LivehallBoard — the hall's own board (the old `/` Astro page, ported
 * 2026-09-24): the tally of the hall, the smiths and their states, one armed
 * errand dealt at a time, and the carved ledger of underway / landed /
 * charted. It reads the same snapshot `bin/hall-snapshot.sh` writes
 * (`/livehall.json`); when the snapshot is stale or absent the saga's own
 * count stands and SAYS so (fail-closed, never invented).
 */
interface Snapshot {
  generated_at?: string;
  realm?: string;
  tally?: { runes?: number; projects?: number; loom?: number; wake?: number; smiths?: number };
  errands_armed?: { errand?: string; smith?: string; priority?: string }[];
  smiths?: { smith?: string; state?: string; pane?: string }[];
  ledger?: { underway?: string[]; landed?: string[]; charted?: string[] };
}

function valid(d: unknown): d is Snapshot {
  const s = d as Snapshot;
  return !!s && typeof s === 'object' && !!s.tally && Array.isArray(s.errands_armed) && !!s.ledger;
}

export default function LivehallBoard() {
  const [snap, setSnap] = useState<Snapshot | null>(null);
  const [error, setError] = useState('');
  const [dealt, setDealt] = useState(0);

  useEffect(() => {
    let alive = true;
    const load = () =>
      fetch('/livehall.json', { signal: AbortSignal.timeout(4000) })
        .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`http ${r.status}`))))
        .then((d) => {
          if (!alive) return;
          if (valid(d)) {
            setSnap(d);
            setError('');
          } else {
            setError('the snapshot is not the hall shape — the saga own board is the truth');
          }
        })
        .catch((e: unknown) => {
          if (!alive) return;
          setError(e instanceof Error && /http 404/.test(e.message) ? 'no livehall.json — the snapshot has not been carved yet (bin/hall-snapshot.sh)' : 'the snapshot did not answer');
        });
    void load();
    const id = window.setInterval(load, 30_000);
    return () => {
      alive = false;
      window.clearInterval(id);
    };
  }, []);

  const t = snap?.tally;
  const errands = snap?.errands_armed ?? [];
  const smiths = snap?.smiths ?? [];
  const ledger = snap?.ledger ?? { underway: [], landed: [], charted: [] };
  const at = dealt % Math.max(errands.length, 1);
  const dealtErrand = errands[at];

  return (
    <>
      <header className="shead">
        <p className="skicker"><span aria-hidden="true">ᛈ</span> óðrœrir · the mead of poetry</p>
        <h1>The Live Hall</h1>
        <p className="ssub">the fleet's planning glass, carved into the cloth — read live, dealt by hand, never a write door</p>
      </header>

      <section className="lh-board panel">
        <div className="panel-body">
          <div className="lh-tally">
            {['runes', 'projects', 'loom', 'wake', 'smiths'].map((k) => (
              <div className="lh-tally-cell" key={k}>
                <b>{(t as Record<string, number> | undefined)?.[k] ?? '—'}</b>
                <span>{k}</span>
              </div>
            ))}
          </div>

          {smiths.length > 0 && (
            <div className="lh-smiths">
              {smiths.map((s) => (
                <span className="lh-smith" key={s.smith ?? Math.random()}>
                  <span className="mono dim">{s.smith}</span>
                  <span className="lh-state">{s.state ?? 'idle'}</span>
                </span>
              ))}
            </div>
          )}

          <div className="lh-cols">
            <section className="lh-sec">
              <div className="lh-sec-head"><span className="lh-eyebrow">ᚲ the hall's call</span></div>
              <div className="lh-call">
                {dealtErrand ? (
                  <p className="lh-call-line">
                    <span className="mono dim">{dealtErrand.smith ? `${dealtErrand.smith}: ` : ''}</span>
                    {dealtErrand.errand ?? '(an unworded errand)'}
                  </p>
                ) : (
                  <p className="mono dim">the pile is empty — nothing armed yet</p>
                )}
              </div>
              {errands.length > 1 && (
                <button type="button" className="td-act" onClick={() => setDealt((v) => v + 1)}>
                  deal the next │ {errands.length} armed
                </button>
              )}
            </section>

            {(['underway', 'landed', 'charted'] as const).map((col) => (
              <section className="lh-sec" key={col}>
                <div className="lh-sec-head"><span className="lh-eyebrow">{col}</span></div>
                <ul className="lh-ledger">
                  {ledger[col]?.map((row, i) => <li key={i} className="mono dim">{row}</li>)}
                  {!(ledger[col]?.length) && <li className="mono dim">—</li>}
                </ul>
              </section>
            ))}
          </div>

          <p className="lh-count mono dim">
            {snap ? `carved ${snap.generated_at ?? ''}${snap.realm ? ` · the ${snap.realm} realm` : ''}` : ''}
          </p>
          {error && <p className="msg err">{error}</p>}
        </div>
      </section>
    </>
  );
}
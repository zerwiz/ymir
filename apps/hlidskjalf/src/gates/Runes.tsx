import { useMemo, useState } from 'react';
import { useYmir } from '../state/store';
import { useUI } from '../state/ui';
import { TraceRow } from '../components/TraceRow';
import { MetricTile } from '../components/MetricTile';
import type { RuneEntry } from '../types';

const LEVELS = ['all', 'ok', 'info', 'warn', 'danger'] as const;

export function Runes() {
  const runes = useYmir((s) => s.runes);
  const realm = useYmir((s) => s.realm);
  const { toast } = useUI();
  const [level, setLevel] = useState<(typeof LEVELS)[number]>('all');
  const [q, setQ] = useState('');

  function exportJsonl() {
    const jsonl = runes.map((r) => JSON.stringify(r)).join('\n');
    const blob = new Blob([jsonl], { type: 'application/x-ndjson' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `runes-${realm}-${new Date().toISOString().slice(0, 10)}.jsonl`;
    a.click();
    URL.revokeObjectURL(url);
    toast({ kind: 'ok', title: 'Runes exported', body: `${runes.length} entries · JSONL` });
  }

  const shown = useMemo(
    () =>
      runes.filter((r) => {
        const levelOk = level === 'all' || r.level === level;
        const qOk =
          q.trim().length === 0 ||
          [r.agent, r.module, r.event, r.order, r.checksum]
            .join(' ')
            .toLowerCase()
            .includes(q.toLowerCase());
        return levelOk && qOk;
      }),
    [runes, level, q],
  );

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Runes</h1>
          <p className="stage-deck">
            Append-only ledger · a rune carved stays carved · checksum chain verified
          </p>
        </div>
        <button className="btn" onClick={exportJsonl}>
          <span aria-hidden="true">ᚱ</span> Export JSONL
        </button>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Entries" value={runes.length} delta="append-strict" spark={[4, 6, 7, 9, 11, runes.length]} />
        <MetricTile label="Chain status" value="VALID" tone="var(--ymir-ok)" delta="head 88aa12" spark={[1, 1, 1, 1, 1]} />
        <MetricTile label="Warnings" value={runes.filter((r) => r.level === 'warn').length} tone="var(--ymir-warn)" delta="degraded" spark={[0, 0, 1, 1, 1]} />
        <MetricTile label="Failures" value={runes.filter((r) => r.level === 'danger').length} tone="var(--ymir-danger)" delta="sealed safely" spark={[0, 1, 1, 1, 1]} />
      </div>

      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᚱ</span>
            Ledger
          </div>
          <div className="row">
            <div className="stream-tabs" role="group" aria-label="Level filter">
              {LEVELS.map((l) => (
                <button
                  key={l}
                  className="stream-tab"
                  aria-pressed={level === l}
                  onClick={() => setLevel(l)}
                >
                  {l}
                </button>
              ))}
            </div>
            <label className="search" style={{ maxWidth: 220, height: 30 }}>
              <span aria-hidden="true">ᛊ</span>
              <input
                value={q}
                onChange={(e) => setQ(e.target.value)}
                placeholder="filter…"
                aria-label="Filter runes"
              />
            </label>
          </div>
        </div>
        <div className="panel-body flush">
          <div className="trace-row" style={{ color: 'var(--ymir-text-2)', fontSize: 10, textTransform: 'uppercase', letterSpacing: '0.1em' }} role="row">
            <span>timestamp</span>
            <span>agent</span>
            <span>module</span>
            <span>event</span>
            <span style={{ textAlign: 'right' }}>checksum</span>
          </div>
          {shown.map((r: RuneEntry) => (
            <TraceRow key={r.id} rune={r} />
          ))}
          {shown.length === 0 ? (
            <div className="empty">
              <span className="glyph" aria-hidden="true">ᚱ</span>
              <p>No rune matches the filter.</p>
            </div>
          ) : null}
        </div>
      </section>
    </>
  );
}

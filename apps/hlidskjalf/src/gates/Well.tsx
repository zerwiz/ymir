import { useYmir } from '../state/store';
import { useUI } from '../state/ui';
import { RecallPanel } from '../components/RecallPanel';
import { MetricTile } from '../components/MetricTile';
import { RuneTag } from '../components/RuneTag';

const TIMELINE = [
  { ts: '09:12', label: 'recall hybrid', detail: '4 episodes, top 0.91', tone: 'var(--ymir-cyan-1)' },
  { ts: '09:26', label: 'veil verdict', detail: 'grounded 0.88 — dispatch approved', tone: 'var(--ymir-ok)' },
  { ts: '09:48', label: 'observe', detail: 'episode 128 carved', tone: 'var(--ymir-violet-1)' },
  { ts: '10:02', label: 'recall cosine', detail: '2 episodes, top 0.78', tone: 'var(--ymir-cyan-1)' },
  { ts: '10:31', label: 'dry well', detail: 'fired cold — never a blocker', tone: 'var(--ymir-warn)' },
];

export function Well() {
  const recall = useYmir((s) => s.recall);
  const { openModal, toast } = useUI();

  function onQuery(q: string) {
    const hits = q.trim()
      ? recall.filter((e) =>
          [e.title, e.body, e.tags.join(' ')].join(' ').toLowerCase().includes(q.toLowerCase()),
        )
      : recall;
    openModal({
      variant: 'info',
      tone: hits.length ? 'info' : 'warn',
      glyph: 'ᛜ',
      title: `Recall — ${q.trim() || 'the whole well'}`,
      body: hits.length
        ? `${hits.length} episode${hits.length === 1 ? '' : 's'} (hybrid) — drink before you act.`
        : 'Dry well. Firing cold — never a blocker.',
      content: hits.length
        ? hits.map((e) => `${e.score.toFixed(2)}  ${e.title}\n    ${e.body}`).join('\n\n')
        : undefined,
    });
    toast({
      kind: hits.length ? 'info' : 'warn',
      title: hits.length ? 'Well recalled' : 'Dry well',
      body: hits.length ? `${hits.length} episodes` : 'firing cold',
    });
  }

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">The Well</h1>
          <p className="stage-deck">
            Mimirsbrunn · engram bridge 127.0.0.1:4602 · drink before you act, water it after
          </p>
        </div>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Episodes observed" value={recall.length} delta="in the well" />
        <MetricTile label="Recall modes" value="3" delta="hybrid · cosine · spreading" />
        <MetricTile label="Well state" value={recall.length ? 'WARM' : 'COLD'} tone={recall.length ? 'var(--ymir-ok)' : 'var(--ymir-warn)'} delta="boost, never blocker" />
        <MetricTile label="Bridge" value=":4602" delta="Mimirsbrunn engram" />
      </div>

      <div className="gate-grid" style={{ gridTemplateColumns: 'minmax(0, 1fr) 360px' }}>
        <RecallPanel episodes={recall} onQuery={onQuery} />

        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛜ</span>
              Timeline
            </div>
          </div>
          <div className="panel-body col" style={{ gap: 'var(--ymir-space-3)' }}>
            {TIMELINE.map((t) => (
              <div className="row" key={t.ts} style={{ alignItems: 'flex-start' }}>
                <span className="mono dim" style={{ fontSize: 11, width: 44 }}>
                  {t.ts}
                </span>
                <span
                  aria-hidden="true"
                  style={{
                    width: 8,
                    height: 8,
                    borderRadius: 4,
                    marginTop: 6,
                    background: t.tone,
                    boxShadow: `0 0 8px ${t.tone}`,
                    flexShrink: 0,
                  }}
                />
                <div className="col">
                  <span style={{ fontSize: 13 }}>{t.label}</span>
                  <span className="mono dim" style={{ fontSize: 11 }}>
                    {t.detail}
                  </span>
                </div>
              </div>
            ))}

            <div className="eyebrow" style={{ marginTop: 'var(--ymir-space-3)' }}>
              Entity graph
            </div>
            <div className="row" style={{ flexWrap: 'wrap', gap: 6 }}>
              <RuneTag label="hlidskjalf" glyph="ᛉ" color="var(--ymir-cyan-1)" />
              <RuneTag label="mimirsbrunn" glyph="ᛜ" color="var(--ymir-violet-1)" />
              <RuneTag label="ratatoskr" glyph="ᛒ" color="var(--ymir-violet-1)" />
              <RuneTag label="utgard" glyph="ᚢ" color="var(--ymir-danger)" />
              <RuneTag label="yggdrasil" glyph="ᛃ" color="var(--ymir-ok)" />
            </div>
          </div>
        </section>
      </div>
    </>
  );
}

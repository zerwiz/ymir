import { useYmir } from '../state/store';
import { useUI } from '../state/ui';
import { RecallPanel } from '../components/RecallPanel';
import { MetricTile } from '../components/MetricTile';
import { RuneTag } from '../components/RuneTag';
import { gateApi } from '../services/api';

const timeOf = (ts: string) => {
  try {
    return new Date(ts).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', hour12: false });
  } catch {
    return '--:--';
  }
};

export function Well() {
  const recall = useYmir((s) => s.recall);
  const mimir = useYmir((s) => s.mimir);
  const { openModal, toast } = useUI();

  const timeline = recall.slice(0, 6).map((e) => ({
    ts: timeOf(e.ts),
    label: e.title,
    detail: `${e.agentScope} · ${e.mode} · ${e.score.toFixed(2)}`,
    tone: e.mode === 'recent' ? 'var(--ymir-warn)' : 'var(--ymir-cyan-1)',
  }));

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
        ? hits
            .map((e) => `**${e.score.toFixed(2)}** · ${e.title}\n\n${e.body}`)
            .join('\n\n---\n\n')
        : undefined,
      format: 'markdown',
    });
    toast({
      kind: hits.length ? 'info' : 'warn',
      title: hits.length ? 'Well recalled' : 'Dry well',
      body: hits.length ? `${hits.length} episodes` : 'firing cold',
    });
  }

  /** Read one memory whole — click an episode and the well opens it. */
  async function onOpen(id: string) {
    try {
      const { episode } = await gateApi.wellEpisode(id);
      const when = episode.timestamp ? new Date(episode.timestamp).toLocaleString('en-GB', { hour12: false }) : '';
      openModal({
        variant: 'info',
        tone: 'info',
        glyph: 'ᛜ',
        title: episode.tags[0] ? `#${episode.tags[0]}` : 'Memory',
        body: `${when}${episode.actors?.length ? ` · ${episode.actors.join(', ')}` : ''}`,
        content: episode.content,
        format: 'markdown',
      });
    } catch {
      toast({ kind: 'warn', title: 'Recall failed', body: 'The well did not answer.' });
    }
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
        <MetricTile label="Episodes observed" value={mimir?.episodes ?? recall.length} delta="in the engram" />
        <MetricTile label="Recall modes" value="3" delta="hybrid · cosine · spreading" />
        <MetricTile label="Well state" value={recall.length ? 'WARM' : 'COLD'} tone={recall.length ? 'var(--ymir-ok)' : 'var(--ymir-warn)'} delta="boost, never blocker" />
        <MetricTile
          label="Bridge"
          value={mimir?.status === 'up' ? 'LIVE' : 'DOWN'}
          tone={mimir?.status === 'up' ? 'var(--ymir-ok)' : 'var(--ymir-danger)'}
          delta={mimir?.store ? mimir.store.split('/').slice(-1)[0] : ':4602 · engram'}
        />
      </div>

      <div className="gate-grid" style={{ gridTemplateColumns: 'minmax(0, 1fr) 360px' }}>
        <RecallPanel episodes={recall} onQuery={onQuery} onOpen={onOpen} />

        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛜ</span>
              Timeline
            </div>
          </div>
          <div className="panel-body col" style={{ gap: 'var(--ymir-space-3)' }}>
            {timeline.length === 0 ? (
              <div className="muted" style={{ fontSize: 12 }}>No episodes yet — water the well.</div>
            ) : (
              timeline.map((t, i) => (
                <div className="row" key={`${t.ts}-${i}`} style={{ alignItems: 'flex-start' }}>
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
              ))
            )}

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

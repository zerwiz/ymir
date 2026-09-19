import { useState } from 'react';
import type { RecallEpisode } from '../types';
import { Markdown } from './Markdown';

/** The store can hand back tags as a comma-string split into CHARACTERS — a
 *  string written where a list was wanted reads as ['r','u','n']. Re-join, then
 *  split, so the panel shows words rather than letters. */
const tagList = (v: unknown): string[] => {
  const arr = Array.isArray(v) ? v.map(String) : String(v ?? '').split(',');
  const joined = arr.join('');
  const parts = joined.includes(',') ? joined.split(',') : arr;
  return parts.map((x) => x.trim()).filter(Boolean);
};

export function RecallPanel({
  episodes,
  onQuery,
  onOpen,
}: {
  episodes: RecallEpisode[];
  onQuery?: (q: string) => void;
  onOpen?: (id: string) => void;
}) {
  const [q, setQ] = useState('');
  const [mode, setMode] = useState<RecallEpisode['mode']>('hybrid');

  const shown = episodes.filter(
    (e) => mode === 'hybrid' || e.mode === mode,
  );

  return (
    <section className="panel">
      <div className="panel-head">
        <div className="panel-title">
          <span className="glyph" aria-hidden="true">ᛜ</span>
          Mimirsbrunn — recall the well
        </div>
        <div className="stream-tabs" role="group" aria-label="Recall mode">
          {(['hybrid', 'cosine', 'spreading'] as const).map((m) => (
            <button
              key={m}
              className="stream-tab"
              aria-pressed={mode === m}
              onClick={() => setMode(m)}
            >
              {m}
            </button>
          ))}
        </div>
      </div>

      <div className="panel-body">
        <form
          className="recall-search"
          onSubmit={(e) => {
            e.preventDefault();
            onQuery?.(q);
          }}
        >
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="what does the well remember about this project?"
            aria-label="Recall query"
          />
          <button className="btn btn-primary" type="submit">
            <span aria-hidden="true">ᛜ</span> Recall
          </button>
        </form>
      </div>

      <div className="panel-body flush">
        {shown.map((ep) => (
          <article
            className="episode episode-link"
            key={ep.id}
            role="button"
            tabIndex={0}
            title="Open the full memory"
            onClick={() => onOpen?.(ep.id)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') onOpen?.(ep.id);
            }}
          >
            <div className="ep-head">
              <div className="ep-title">{ep.title}</div>
              <div className="row">
                <div className="score-bar" aria-hidden="true">
                  <span style={{ width: `${Math.round(ep.score * 100)}%` }} />
                </div>
                <span className="score-val">{ep.score.toFixed(2)}</span>
              </div>
            </div>
            <div className="ep-body">
              <Markdown source={ep.body} />
            </div>
            <div className="ep-foot">
              <span>{ep.mode}</span>
              <span>{ep.agentScope}</span>
              <span>{new Date(ep.ts).toLocaleString('en-GB', { hour12: false })}</span>
              {tagList(ep.tags).map((t) => (
                <span key={t}>#{t}</span>
              ))}
            </div>
          </article>
        ))}
        {shown.length === 0 ? (
          <div className="empty">
            <span className="glyph" aria-hidden="true">ᛜ</span>
            <p>Dry well. Firing cold — never a blocker.</p>
          </div>
        ) : null}
      </div>
    </section>
  );
}

import {
  useState,
  type PointerEvent as ReactPointerEvent,
  type KeyboardEvent as ReactKeyboardEvent,
} from 'react';
import { useYmir } from '../state/store';
import type { StreamEvent } from '../types';

function fmt(ts: string) {
  const d = new Date(ts);
  return (
    d.toLocaleTimeString('en-GB', { hour12: false }) +
    '.' +
    String(d.getMilliseconds()).padStart(3, '0')
  );
}

export function BottomStream() {
  const stream = useYmir((s) => s.stream);
  const paused = useYmir((s) => s.streamPaused);
  const toggle = useYmir((s) => s.toggleStream);
  const streamHeight = useYmir((s) => s.streamHeight);
  const setStreamHeight = useYmir((s) => s.setStreamHeight);
  const [filter, setFilter] = useState<'all' | StreamEvent['kind']>('all');

  const shown = (filter === 'all' ? stream : stream.filter((e) => e.kind === filter)).slice(0, 60);

  function beginResize(e: ReactPointerEvent<HTMLDivElement>) {
    e.preventDefault();
    const startY = e.clientY;
    const startH = streamHeight;
    const move = (ev: PointerEvent) => setStreamHeight(startH + (startY - ev.clientY));
    const end = () => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', end);
      document.body.style.cursor = '';
    };
    document.body.style.cursor = 'ns-resize';
    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', end);
  }

  function resizeKey(e: ReactKeyboardEvent<HTMLDivElement>) {
    if (e.key === 'ArrowUp') {
      e.preventDefault();
      setStreamHeight(streamHeight + 24);
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      setStreamHeight(streamHeight - 24);
    } else if (e.key === 'Home') {
      e.preventDefault();
      setStreamHeight(192);
    }
  }

  return (
    <footer className="stream" aria-label="Ratatoskr and Runes stream">
      <div
        className="stream-resizer"
        role="separator"
        aria-orientation="horizontal"
        aria-label="Resize stream — drag up or down"
        aria-valuenow={streamHeight}
        tabIndex={0}
        onPointerDown={beginResize}
        onKeyDown={resizeKey}
        onDoubleClick={() => setStreamHeight(192)}
        title="Drag to resize · double-click to reset"
      >
        <span className="grip" aria-hidden="true" />
      </div>

      <div className="stream-head">
        <span className={`live-dot ${paused ? 'paused' : ''}`} aria-hidden="true" />
        <span className="stream-title">The Stream</span>
        <span className="mono dim" style={{ fontSize: 10 }}>
          ratatoskr · runes
        </span>

        <div className="stream-tabs" role="group" aria-label="Stream filter">
          {(['all', 'ratatoskr', 'rune'] as const).map((f) => (
            <button
              key={f}
              className="stream-tab"
              aria-pressed={filter === f}
              onClick={() => setFilter(f)}
            >
              {f === 'rune' ? 'runes' : f}
            </button>
          ))}
        </div>

        <div className="grow" />

        <button className="btn btn-sm" onClick={toggle} aria-pressed={paused}>
          <span className="glyph" aria-hidden="true">{paused ? '▶' : '❚❚'}</span>
          {paused ? 'Resume' : 'Pause'}
        </button>
      </div>

      <div className="stream-body" role="log" aria-live="polite">
        {shown.map((e) => (
          <div className="stream-line" key={e.id}>
            <span className="ts">{fmt(e.ts)}</span>
            <span className="actor">
              {e.from}
              {e.to ? <span className="to"> → {e.to}</span> : null}
            </span>
            <span className="msg" title={e.message}>
              {e.message}
            </span>
            <span className={`kind ${e.kind}`}>
              {e.kind === 'rune' ? `◆ ${e.module ?? 'runes'}` : `⇄ ${e.state ?? 'A2A'}`}
            </span>
          </div>
        ))}
      </div>
    </footer>
  );
}

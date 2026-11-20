import { useRef, useState } from 'react';
import { GATES } from '../data/realms';
import { useYmir } from '../state/store';

const PRIMARY = ['fleet', 'tasks', 'well', 'chat'];

/** The phone's gate navigation: a bottom tab bar + a "More" sheet. */
export function MobileNav() {
  const gate = useYmir((s) => s.gate);
  const setGate = useYmir((s) => s.setGate);
  const [more, setMore] = useState(false);
  const [dragY, setDragY] = useState(0);
  const startY = useRef<number | null>(null);

  function gripDown(e: React.PointerEvent) {
    e.preventDefault();
    startY.current = e.clientY;
    const move = (ev: PointerEvent) => {
      if (startY.current == null) return;
      setDragY(Math.max(0, ev.clientY - startY.current));
    };
    const end = () => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', end);
      startY.current = null;
      setDragY((y) => {
        if (y > 80) setMore(false);
        return 0;
      });
    };
    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', end);
  }

  const primaries = PRIMARY.map((id) => GATES.find((g) => g.id === id)).filter(Boolean) as typeof GATES;
  const rest = GATES.filter((g) => !PRIMARY.includes(g.id));

  return (
    <>
      <nav className="m-nav" aria-label="Gates">
        {primaries.map((g) => (
          <button
            key={g.id}
            className={`m-tab ${gate === g.id ? 'on' : ''}`}
            onClick={() => setGate(g.id)}
            aria-current={gate === g.id ? 'page' : undefined}
          >
            <span className="m-glyph" aria-hidden="true">{g.glyph}</span>
            <span>{g.label}</span>
          </button>
        ))}
        <button className={`m-tab ${more ? 'on' : ''}`} onClick={() => setMore(true)} aria-haspopup="dialog">
          <span className="m-glyph" aria-hidden="true">ᛜ</span>
          <span>More</span>
        </button>
      </nav>

      {more ? (
        <div className="m-sheet" role="dialog" aria-modal="true" aria-label="All gates" onClick={() => setMore(false)}>
          <div
            className="m-sheet-inner"
            onClick={(e) => e.stopPropagation()}
            style={{ transform: `translateY(${dragY}px)`, transition: dragY ? "none" : "transform .18s ease" }}
          >
            <div className="m-sheet-grip" onPointerDown={gripDown} role="separator" aria-label="Swipe down to close" />
            <div className="m-sheet-head">All gates</div>
            <div className="m-grid">
              {rest.map((g) => (
                <button
                  key={g.id}
                  className={`m-cell ${gate === g.id ? 'on' : ''}`}
                  onClick={() => {
                    setGate(g.id);
                    setMore(false);
                  }}
                >
                  <span className="m-glyph" aria-hidden="true">{g.glyph}</span>
                  <span>{g.label}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}

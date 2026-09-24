import { useEffect, useState } from 'react';
import EmberBackground from './components/EmberBackground';
import TicketsBoard from './components/TicketsBoard';
import PlansBoard from './components/PlansBoard';

/**
 * Óðrerir — the Live Hall, rebuilt as a Hlidskjalf-type app (plan 55,
 * 2026-09-24): the ember hearth, the translucent panels, and the halls
 * buttons in the same design as the high seat. The board itself — tickets +
 * plans — rides the Skuld door; the shell is the same cloth.
 */

// The three halls, one hinge: these buttons raise the other Ymir windows
// through the Hlidskjalf gate, exactly as the high seat's own switcher does.
const HALLS = [
  { id: 'hlidskjalf', glyph: 'ᚺ', name: 'Hlidskjalf' },
  { id: 'smidja', glyph: 'ᛊ', name: 'Smíðja' },
  { id: 'sessrumnir', glyph: 'ᛋ', name: 'Sessrúmnir' },
  { id: 'odrerir', glyph: 'ᛟ', name: 'Óðrerir' },
];

function raiseHall(id: string) {
  if (id === 'odrerir') return; // you are here
  fetch('http://127.0.0.1:3889/api/desktop', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ view: id }),
    signal: AbortSignal.timeout(2500),
  }).catch(() => undefined); // a quiet gate never breaks the board
}

type View = 'tickets' | 'plans';
function viewFromHash(): View {
  const h = window.location.hash.replace(/^#\/?/, '');
  return h === 'plans' ? 'plans' : 'tickets';
}

export default function App() {
  const [view, setView] = useState<View>(viewFromHash);
  useEffect(() => {
    const onHash = () => setView(viewFromHash());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  return (
    <>
      <EmberBackground />
      <div className="hall-top">
        <span className="hall-mast">
          <span aria-hidden="true">ᛟ</span> YMIR · ÓÐRERIR — THE LIVE HALL
        </span>
        <span className="hall-links">
          {(['tickets', 'plans'] as const).map((v) => (
            <a
              key={v}
              className="hall-back"
              href={`#/${v}`}
              data-here={view === v ? '1' : undefined}
            >
              {v === 'tickets' ? 'the tickets' : 'the plans'}
            </a>
          ))}
        </span>
        <span className="hall-btns" role="group" aria-label="the halls">
          {HALLS.map((h) => (
            <button
              key={h.id}
              type="button"
              className="hall-btn"
              aria-pressed={h.id === 'odrerir'}
              onClick={() => raiseHall(h.id)}
            >
              <span aria-hidden="true">{h.glyph}</span>
              {h.name}
            </button>
          ))}
        </span>
      </div>
      <main className="hall-wrap">
        {view === 'tickets' ? <TicketsBoard /> : <PlansBoard />}
      </main>
    </>
  );
}
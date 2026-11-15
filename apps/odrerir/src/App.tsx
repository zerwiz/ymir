import { useEffect, useState } from 'react';
import EmberBackground from './components/EmberBackground';
import LivehallBoard from './components/LivehallBoard';
import NearBoard from './components/NearBoard';
import TicketsBoard from './components/TicketsBoard';
import PlansBoard from './components/PlansBoard';

/**
 * Óðrerir — the Live Hall (plan 55): the ember hearth, the translucent panels,
 * and its OWN doors — `#/` the board, `#/near` the near loop, `#/tickets`,
 * `#/plans`. The halls buttons that raised the other three windows are gone
 * (plan 275 item 32): every app opens from its own desktop icon, so no header
 * carries a launcher for a sibling app. What stays is this hall's own nav.
 */

type View = 'hall' | 'tickets' | 'plans' | 'near';
function viewFromHash(): View {
  const h = window.location.hash.replace(/^#\/?/, '');
  if (h === 'tickets') return 'tickets';
  if (h === 'plans') return 'plans';
  if (h === 'near') return 'near';
  return 'hall';
}

const DOORS: { id: View; label: string }[] = [
  { id: 'hall', label: 'the board' },
  { id: 'near', label: 'the near loop' },
  { id: 'tickets', label: 'the tickets' },
  { id: 'plans', label: 'the plans' },
];

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
          {DOORS.map((d) => (
            <a
              key={d.id}
              className="hall-back"
              href={`#/${d.id == null ? '' : d.id === 'hall' ? '' : d.id}`}
              data-here={view === d.id ? '1' : undefined}
            >
              {d.label}
            </a>
          ))}
        </span>
      </div>
      <main className={view === 'hall' ? 'hall-stage' : 'hall-wrap'}>
        {view === 'hall' ? (
          <LivehallBoard />
        ) : view === 'tickets' ? (
          <TicketsBoard />
        ) : view === 'plans' ? (
          <PlansBoard />
        ) : (
          <NearBoard />
        )}
      </main>
    </>
  );
}
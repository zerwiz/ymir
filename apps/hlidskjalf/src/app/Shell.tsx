import { lazy, Suspense, useEffect, type ComponentType, type CSSProperties } from 'react';
import { useYmir } from '../state/store';
import { GATES, realmDef } from '../data/realms';
import { applyMeta } from '../data/metadata';
import { Rail } from './Rail';
import { Topbar } from './Topbar';
import { BottomStream } from './BottomStream';
import { MobileNav } from './MobileNav';

// ── the gates load when they are opened, not before the first screen (2026-11-14, plan 275 item 10) ───────
// Every gate used to be a static import, so the renderer parsed and executed all twenty-one pages — Fleet,
// Stats, Managandr, Snotra, Mail and the rest — before the first screen could paint. Under this seat's
// `software` graphics policy (bin/host/graphics-lib.sh; the hybrid card forces CPU rasterisation) that cost
// showed up as a white window: measured 9.46 s from window mapped to first answer. One screen needs one gate,
// so each is now its own chunk, fetched on first open and kept afterwards (React caches the module). Nothing is
// removed: every page is still there, still the same component, only later. The rail, the top bar, the stream
// and the mobile nav stay eager — they ARE the first screen.
const lazyGate = (load: () => Promise<Record<string, unknown>>, name: string) =>
  lazy(() => load().then((m) => ({ default: m[name] as ComponentType })));

const Fleet = lazyGate(() => import('../gates/Fleet'), 'Fleet');
const Tasks = lazyGate(() => import('../gates/Tasks'), 'Tasks');
const Well = lazyGate(() => import('../gates/Well'), 'Well');
const Runes = lazyGate(() => import('../gates/Runes'), 'Runes');
const Reviews = lazyGate(() => import('../gates/Reviews'), 'Reviews');
const Processes = lazyGate(() => import('../gates/Processes'), 'Processes');
const Files = lazyGate(() => import('../gates/Files'), 'Files');
const OmniChat = lazyGate(() => import('../gates/OmniChat'), 'OmniChat');
const Skirnir = lazyGate(() => import('../gates/Skirnir'), 'Skirnir');
const Forge = lazyGate(() => import('../gates/Forge'), 'Forge');
const Profile = lazyGate(() => import('../gates/Profile'), 'Profile');
const Runtime = lazyGate(() => import('../gates/Runtime'), 'Runtime');
const Cron = lazyGate(() => import('../gates/Cron'), 'Cron');
const Sessions = lazyGate(() => import('../gates/Sessions'), 'Sessions');
const Worktrees = lazyGate(() => import('../gates/Worktrees'), 'Worktrees');
const Trace = lazyGate(() => import('../gates/Trace'), 'Trace');
const Decisions = lazyGate(() => import('../gates/Decisions'), 'Decisions');
const Stats = lazyGate(() => import('../gates/Stats'), 'Stats');
const Managandr = lazyGate(() => import('../gates/Managandr'), 'Managandr');
const Snotra = lazyGate(() => import('../gates/Snotra'), 'Snotra');
const Mail = lazyGate(() => import('../gates/Mail'), 'Mail');

function Stage() {
  const gate = useYmir((s) => s.gate);
  switch (gate) {
    case 'fleet':
      return <Fleet />;
    case 'tasks':
      return <Tasks />;
    case 'well':
      return <Well />;
    case 'runes':
      return <Runes />;
    case 'reviews':
      return <Reviews />;
    case 'processes':
      return <Processes />;
    case 'files':
      return <Files />;
    case 'chat':
      return <OmniChat />;
    case 'skirnir':
      return <Skirnir />;
    case 'forge':
      return <Forge />;
    case 'profile':
      return <Profile />;
    case 'runtime':
      return <Runtime />;
    case 'cron':
      return <Cron />;
    case 'sessions':
      return <Sessions />;
    case 'worktrees':
      return <Worktrees />;
    case 'trace':
      return <Trace />;
    case 'decisions':
      return <Decisions />;
    case 'stats':
      return <Stats />;
    case 'managandr':
      return <Managandr />;
    case 'snotra':
      return <Snotra />;
    case 'mail':
      return <Mail />;
    default:
      return <Fleet />;
  }
}

function PageFeed() {
  const streams = useYmir((s) => s.streams);
  const gate = useYmir((s) => s.gate);
  const items = (streams[gate]?.length ? streams[gate] : streams.all ?? []).slice(0, 3);
  return (
    <div className="page-feed" aria-live="polite" title="Live page feed — last 40">
      {items.length === 0 ? (
        <span className="pf-line dim">awaiting the first message…</span>
      ) : (
        items.map((e) => (
          <span className="pf-line" key={e.id}>
            <span className="pf-ts">
              {new Date(e.ts).toLocaleTimeString('en-GB', { hour12: false })}
            </span>
            <span className="pf-from">{e.from}</span>
            <span className="pf-msg" title={e.message}>
              {e.message}
            </span>
          </span>
        ))
      )}
    </div>
  );
}

export function Shell() {
  const realm = useYmir((s) => s.realm);
  const session = useYmir((s) => s.session);
  const density = useYmir((s) => s.density);
  const gate = useYmir((s) => s.gate);
  const streamHeight = useYmir((s) => s.streamHeight);

  const gateDef = GATES.find((g) => g.id === gate);
  const tenant = session?.tenants.find((t) => t.realm === realm);
  const def = realmDef(realm, tenant);

  useEffect(() => {
    applyMeta(gate, def.tenant);
  }, [gate, def.tenant]);

  return (
    <div
      className="shell"
      data-realm={realm}
      data-density={density}
      style={{ '--stream-h': `${streamHeight}px` } as CSSProperties}
    >
      <Rail />
      <Topbar />
      <main className="stage" role="main">
        <div className="stage-header-row">
          {gateDef ? (
            <div className="stage-deck">
              <span aria-hidden="true">{gateDef.glyph}</span> {gateDef.hint}
            </div>
          ) : (
            <span />
          )}
          <PageFeed />
        </div>
        <Suspense fallback={<div className="stage-loading dim" aria-busy="true">opening…</div>}>
          <Stage />
        </Suspense>
      </main>
      <BottomStream />
      <MobileNav />
    </div>
  );
}

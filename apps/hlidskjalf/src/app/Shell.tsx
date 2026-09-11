import { useEffect, type CSSProperties } from 'react';
import { useYmir } from '../state/store';
import { GATES, realmDef } from '../data/realms';
import { applyMeta } from '../data/metadata';
import { Rail } from './Rail';
import { Topbar } from './Topbar';
import { BottomStream } from './BottomStream';
import { Fleet } from '../gates/Fleet';
import { Tasks } from '../gates/Tasks';
import { Well } from '../gates/Well';
import { Runes } from '../gates/Runes';
import { Reviews } from '../gates/Reviews';
import { Processes } from '../gates/Processes';
import { Files } from '../gates/Files';
import { OmniChat } from '../gates/OmniChat';
import { Forge } from '../gates/Forge';
import { Profile } from '../gates/Profile';
import { Runtime } from '../gates/Runtime';
import { Cron } from '../gates/Cron';

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
    case 'forge':
      return <Forge />;
    case 'profile':
      return <Profile />;
    case 'runtime':
      return <Runtime />;
    case 'cron':
      return <Cron />;
    default:
      return <Fleet />;
  }
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
        {gateDef ? (
          <div className="stage-deck" style={{ marginBottom: 'var(--ymir-space-4)' }}>
            <span aria-hidden="true">{gateDef.glyph}</span> {gateDef.hint}
          </div>
        ) : null}
        <Stage />
      </main>
      <BottomStream />
    </div>
  );
}

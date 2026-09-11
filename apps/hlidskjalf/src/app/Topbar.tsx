import { useState } from 'react';
import { useYmir } from '../state/store';
import { WORKSPACES } from '../data/realms';
import { gateApi } from '../services/api';
import { AccentPicker } from '../components/AccentPicker';
import { AccountMenu } from '../components/AccountMenu';

export function Topbar() {
  const realm = useYmir((s) => s.realm);
  const setRealm = useYmir((s) => s.setRealm);
  const session = useYmir((s) => s.session);
  const query = useYmir((s) => s.query);
  const setQuery = useYmir((s) => s.setQuery);
  const density = useYmir((s) => s.density);
  const setDensity = useYmir((s) => s.setDensity);
  const trace = useYmir((s) => s.traceability);
  const [adding, setAdding] = useState(false);

  // Single tenant: the switchable unit is a workspace. Union of the known ones
  // and any granted to the session.
  const ids = Array.from(new Set([...WORKSPACES.map((w) => w.id), ...(session?.tenants.map((t) => t.realm) ?? [])]));
  const list = ids.map((id) => WORKSPACES.find((w) => w.id === id) ?? { id, tenant: id, name: id, glyph: 'ᛗ', tint: '', tint2: '' });

  async function addWorkspace() {
    const name = window.prompt('New workspace name');
    if (!name) return;
    setAdding(true);
    const slug = name.toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/(^-|-$)/g, '');
    try {
      await gateApi.createWorkspace({ name: slug, kind: 'personal', domains: ['life', 'development'] });
    } catch {
      /* gate API offline — still switch locally */
    }
    setAdding(false);
    if (slug) setRealm(slug);
  }

  return (
    <header className="topbar">
      <div className="ws-switch" role="group" aria-label="Workspace">
        {list.map((w) => (
          <button
            key={w.id}
            className={`ws-chip ${w.id === realm ? 'on' : ''}`}
            onClick={() => setRealm(w.id)}
            title={`Workspace · ${w.name ?? w.id}`}
          >
            <span className="house-glyph" aria-hidden="true">
              {w.glyph}
            </span>
            {w.name ?? w.id}
          </button>
        ))}
        <button className="ws-chip add" onClick={addWorkspace} disabled={adding} title="New workspace">
          ＋
        </button>
      </div>

      <label className="search">
        <span aria-hidden="true">ᛊ</span>
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={`Search ${realm} workspace…`}
          aria-label="Workspace-scoped search"
        />
        <kbd>/</kbd>
      </label>

      <div className="topbar-spacer" />

      <AccentPicker />

      <button
        className="icon-btn"
        aria-pressed={density === 'compact'}
        onClick={() => setDensity(density === 'compact' ? 'comfortable' : 'compact')}
        title="Compact density"
      >
        {density === 'compact' ? 'ᛃ' : 'ᚼ'}
      </button>

      <div className="trace-chip" title="Live traceability index (target 0.984)">
        <span className="label">Trace</span>
        <span className="value">{trace.toFixed(3)}</span>
      </div>

      <AccountMenu />
    </header>
  );
}

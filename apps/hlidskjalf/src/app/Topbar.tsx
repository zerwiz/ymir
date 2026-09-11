import { useYmir } from '../state/store';
import { HOUSES } from '../data/realms';
import { ROLE_LABEL } from '../services/auth';
import { useTenantDef } from '../hooks/useTenantDef';
import { AccentPicker } from '../components/AccentPicker';
import { AccountMenu } from '../components/AccountMenu';

export function Topbar() {
  const realm = useYmir((s) => s.realm);
  const session = useYmir((s) => s.session);
  const query = useYmir((s) => s.query);
  const setQuery = useYmir((s) => s.setQuery);
  const density = useYmir((s) => s.density);
  const setDensity = useYmir((s) => s.setDensity);
  const trace = useYmir((s) => s.traceability);

  const tenant = session?.tenants.find((t) => t.realm === realm);
  const def = useTenantDef(realm, tenant);
  const house = HOUSES[tenant?.house ?? def.house];

  return (
    <header className="topbar">
      <div className="realm-chip" title={`${def.tenant} · ${house.name}`}>
        <span className="house-glyph" aria-hidden="true">
          {house.glyph}
        </span>
        <span>{def.tenant}</span>
        <span className="dim">·</span>
        <span style={{ color: house.accent }}>{house.name}</span>
        {tenant ? (
          <>
            <span className="dim">·</span>
            <span className="dim" style={{ textTransform: 'uppercase', fontSize: 10 }}>
              {ROLE_LABEL[tenant.role]}
            </span>
          </>
        ) : null}
      </div>

      <label className="search">
        <span aria-hidden="true">ᛊ</span>
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={`Search ${def.tenant} realm…`}
          aria-label="Realm-scoped search"
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

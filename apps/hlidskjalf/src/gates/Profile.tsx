import { useState } from 'react';
import { useYmir } from '../state/store';
import { useUI } from '../state/ui';
import { ACCENTS, HOUSES } from '../data/realms';
import { ROLE_LABEL } from '../services/auth';
import { useTenantDef } from '../hooks/useTenantDef';
import type { HouseId } from '../types';

const HOUSES_LIST = Object.keys(HOUSES) as HouseId[];

function TenantColorRow({ realm, tenant, role, house, glyph }: {
  realm: string;
  tenant: string;
  role: keyof typeof ROLE_LABEL;
  house: HouseId;
  glyph: string;
}) {
  const colors = useYmir((s) => s.tenantColors);
  const setTenantColor = useYmir((s) => s.setTenantColor);
  const resetTenantColor = useYmir((s) => s.resetTenantColor);
  const def = useTenantDef(realm, { realm, tenant, role, house, tint: '#38bdf8', glyph });
  const override = colors[realm];
  const houseDef = HOUSES[house];

  return (
    <div className="tenant-row">
      <span className="realm-swatch" style={{ background: def.tint }} />
      <div className="col grow" style={{ minWidth: 0 }}>
        <span className="row" style={{ gap: 8 }}>
          <strong>{tenant}</strong>
          <span className="mono dim" style={{ fontSize: 10, textTransform: 'uppercase' }}>
            {ROLE_LABEL[role]}
          </span>
        </span>
        <span className="mono dim" style={{ fontSize: 11 }}>
          {houseDef.name} · seal {houseDef.glyph}
        </span>
      </div>
      <input
        type="color"
        value={override ?? def.tint}
        onChange={(e) => setTenantColor(realm, e.target.value)}
        aria-label={`${tenant} colour`}
      />
      <button className="btn btn-sm" onClick={() => resetTenantColor(realm)} disabled={!override}>
        Reset
      </button>
    </div>
  );
}

export function Profile() {
  const session = useYmir((s) => s.session);
  const accentId = useYmir((s) => s.accentId);
  const custom = useYmir((s) => s.customAccent);
  const setAccent = useYmir((s) => s.setAccent);
  const setCustom = useYmir((s) => s.setCustomAccent);
  const density = useYmir((s) => s.density);
  const setDensity = useYmir((s) => s.setDensity);
  const companyName = useYmir((s) => s.companyName);
  const companyHouse = useYmir((s) => s.companyHouse);
  const setCompanyName = useYmir((s) => s.setCompanyName);
  const setCompanyHouse = useYmir((s) => s.setCompanyHouse);
  const { toast } = useUI();
  const [draftName, setDraftName] = useState(companyName);

  if (!session) return null;

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Profile</h1>
          <p className="stage-deck">Personal settings · tenant colours · company settings</p>
        </div>
      </div>

      <div className="gate-grid cols-2">
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛝ</span> Personal
            </div>
          </div>
          <div className="panel-body col" style={{ gap: 'var(--ymir-space-4)' }}>
            <div className="row" style={{ gap: 'var(--ymir-space-3)' }}>
              <span className="avatar" aria-hidden="true">{session.user.avatar}</span>
              <div className="col" style={{ lineHeight: 1.3 }}>
                <strong>{session.user.name}</strong>
                <span className="mono dim" style={{ fontSize: 11 }}>{session.user.email}</span>
                <span className="mono dim" style={{ fontSize: 11 }}>@{session.user.login} · via {session.method}</span>
              </div>
            </div>

            <div className="field">
              <span className="eyebrow">Accent — paint your own seat</span>
              <div className="swatch-grid" style={{ padding: 0 }}>
                {ACCENTS.map((a) => (
                  <button
                    key={a.id}
                    className="swatch"
                    aria-pressed={accentId === a.id}
                    title={a.name}
                    onClick={() => setAccent(a.id)}
                    style={a.tint ? { background: a.tint } : { background: 'linear-gradient(135deg,#38bdf8,#8b5cf6,#f59e0b)' }}
                  >
                    {a.id === 'realm' ? <span className="swatch-realm" aria-hidden="true">ᛉ</span> : null}
                    {accentId === a.id ? <span className="swatch-check" aria-hidden="true">✓</span> : null}
                  </button>
                ))}
              </div>
            </div>

            <label className="field">
              <span className="eyebrow">Custom accent</span>
              <div className="row">
                <input
                  type="color"
                  value={custom ?? '#38bdf8'}
                  onChange={(e) => setCustom(e.target.value)}
                  style={{ width: 44, height: 34, border: '1px solid var(--ymir-steel-1)', borderRadius: 8, background: 'none' }}
                />
                <span className="mono dim">{accentId === 'custom' ? custom : 'pick a hex'}</span>
              </div>
            </label>

            <div className="field">
              <span className="eyebrow">Density</span>
              <div className="row">
                <button className="btn" aria-pressed={density === 'comfortable'} onClick={() => setDensity('comfortable')}>Comfortable</button>
                <button className="btn" aria-pressed={density === 'compact'} onClick={() => setDensity('compact')}>Compact</button>
              </div>
            </div>
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛊ</span> Workspace colours
            </div>
            <span className="mono dim" style={{ fontSize: 10 }}>one tenant · many scopes</span>
          </div>
          <div className="panel-body col" style={{ gap: 'var(--ymir-space-3)' }}>
            {session.tenants.map((t) => (
              <TenantColorRow
                key={t.realm}
                realm={t.realm}
                tenant={t.tenant}
                role={t.role}
                house={t.house}
                glyph={t.glyph}
              />
            ))}
            <p className="mono dim" style={{ fontSize: 11 }}>
              Each workspace swatch repaints that workspace's tint. Set accent to “Realm default” to follow it.
            </p>
          </div>
        </section>

        <section className="panel span-2">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛒ</span> Company
            </div>
          </div>
          <div className="panel-body col" style={{ gap: 'var(--ymir-space-4)' }}>
            <div className="form-grid">
              <label className="field">
                <span className="eyebrow">Company name</span>
                <input
                  value={draftName}
                  onChange={(e) => setDraftName(e.target.value)}
                  placeholder="WayOf"
                />
              </label>
              <label className="field">
                <span className="eyebrow">House seal</span>
                <select value={companyHouse} onChange={(e) => setCompanyHouse(e.target.value as HouseId)}>
                  {HOUSES_LIST.map((h) => (
                    <option key={h} value={h}>{HOUSES[h].name}</option>
                  ))}
                </select>
              </label>
            </div>

            <div className="eyebrow">Workspaces</div>
            <div className="col" style={{ gap: 6 }}>
              {session.tenants.map((t) => (
                <div className="tenant-row" key={t.realm}>
                  <span className="realm-swatch" style={{ background: tenantColorOf(t.realm, t.tint) }} />
                  <span className="grow">
                    @{session.user.login}
                    <span className="mono dim" style={{ marginLeft: 8, fontSize: 11 }}>{t.tenant}</span>
                  </span>
                  <span className="mono dim" style={{ fontSize: 10, textTransform: 'uppercase' }}>
                    {ROLE_LABEL[t.role]}
                  </span>
                </div>
              ))}
            </div>

            <div className="row">
              <button
                className="btn btn-primary"
                onClick={() => {
                  setCompanyName(draftName.trim() || 'WayOf');
                  toast({ kind: 'ok', title: 'Company saved', body: `${draftName} · ${HOUSES[companyHouse].name}` });
                }}
              >
                <span aria-hidden="true">ᛉ</span> Save company
              </button>
              <button className="btn" onClick={() => setDraftName(companyName)}>Reset</button>
            </div>
          </div>
        </section>
      </div>
    </>
  );
}

// reading tenant colors outside the render hook graph (safe: not a hook)
function tenantColorOf(realm: string, fallback: string): string {
  return useYmir.getState().tenantColors[realm] ?? fallback;
}

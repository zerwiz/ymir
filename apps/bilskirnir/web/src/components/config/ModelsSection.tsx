import { useCallback, useEffect, useMemo, useState } from 'react';
import { configApi, type ModelProvider, type ModelsView } from '../../lib/configApi';
import { useStore } from '../../store';

/**
 * Settings › Models. What the user already has, found for them, and one click to use it.
 * The server looks (environment, pi, OpenCode, Hermes, local servers); nothing is typed except,
 * at most, a key for a provider they pick from the list. Keys never come back to this page.
 */

const SHOW = 8;

function statusChip(p: ModelProvider) {
  if (p.status === 'ok') return <span className="cfg-chip">{p.local ? 'On this computer' : 'Connected'}</span>;
  if (p.status === 'needs-key') return <span className="cfg-chip cfg-chip--muted">Needs a key</span>;
  if (p.status === 'from-config') return <span className="cfg-chip cfg-chip--muted">{p.note ?? 'Not answering'}</span>;
  return <span className="cfg-chip cfg-chip--muted">Not answering</span>;
}

function ProviderCard({ p, agent, current, busy, onUse, onRemove, query }: {
  p: ModelProvider; agent: { id: string; name: string }; current: { providerId: string | null; model: string | null };
  busy: string | null; onUse: (providerId: string, model: string) => void; onRemove: (id: string) => void; query: string;
}) {
  const [all, setAll] = useState(false);
  const q = query.trim().toLowerCase();
  const rows = q ? p.models.filter((m) => m.id.toLowerCase().includes(q)) : p.models;
  if (q && !rows.length) return null;
  const shown = all || q ? rows : rows.slice(0, SHOW);
  const needsKey = !p.local && !p.hasKey;
  return (
    <section className="cfg-section models-provider">
      <div className="cfg-card">
        <div className="cfg-row models-provider__head">
          <div className="cfg-row__text">
            <div className="cfg-row__title">{p.name} {statusChip(p)}</div>
            <div className="cfg-row__sub">Found: {p.sources.join('; ')}{p.hasKey ? ` · key from ${p.key}` : p.local ? '' : ' · no key yet'}</div>
          </div>
          {p.added && <button type="button" className="cfg-btn cfg-btn--ghost-danger" onClick={() => onRemove(p.id)}>Remove</button>}
        </div>
        {needsKey && <div className="cfg-field__hint models-note">Add a key below to use this provider’s models.</div>}
        {shown.length === 0 && <div className="cfg-empty cfg-empty--flat">{p.status === 'ok' ? 'It lists no models.' : 'No models to show while it is not answering.'}</div>}
        {shown.map((m) => {
          const inUse = current.providerId === p.id && current.model === m.id;
          const key = `${p.id}/${m.id}`;
          return (
            <div key={m.id} className={`cfg-row models-row${m.allowed ? '' : ' is-refused'}`}>
              <div className="cfg-row__text">
                <div className="cfg-row__title models-row__id">{m.id}</div>
                {!m.allowed && <div className="cfg-row__sub">{m.reason ?? 'not allowed in this fleet'}</div>}
              </div>
              {inUse ? <span className="cfg-chip">In use by {agent.name}</span> : (
                <button type="button" className="cfg-btn cfg-btn--secondary" disabled={!m.allowed || needsKey || busy !== null}
                  title={!m.allowed ? 'not allowed in this fleet' : needsKey ? 'add a key first' : undefined}
                  onClick={() => onUse(p.id, m.id)}>
                  {busy === key ? 'Switching…' : `Use for ${agent.name}`}
                </button>
              )}
            </div>
          );
        })}
        {!q && rows.length > SHOW && (
          <div className="cfg-row"><button type="button" className="cfg-btn cfg-btn--secondary" onClick={() => setAll(!all)}>{all ? 'Show fewer' : `Show all ${rows.length}`}</button></div>
        )}
      </div>
    </section>
  );
}

function AddProvider({ view, onAdded }: { view: ModelsView; onAdded: () => void }) {
  const [preset, setPreset] = useState('');
  const [name, setName] = useState('');
  const [baseUrl, setBaseUrl] = useState('');
  const [key, setKey] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);
  const chosen = view.presets.find((p) => p.id === preset);
  const custom = preset === '' || preset === 'other';
  const needKey = chosen ? chosen.needsKey : true;
  const canAdd = !busy && (custom ? /^https?:\/\//.test(baseUrl.trim()) : !chosen?.needsKey || key.trim().length > 0);

  const add = async () => {
    setBusy(true); setErr(null); setDone(null);
    try {
      const r = await configApi.addProvider({ preset: custom ? undefined : preset, name: name.trim() || undefined, baseUrl: custom || baseUrl.trim() ? baseUrl.trim() || undefined : undefined, key: key.trim() || undefined });
      setDone(r.keyStoredIn ? `Added. The key is kept in ${r.keyStoredIn}, and never shown again.` : 'Added.');
      setKey(''); setBaseUrl(''); setName(''); setPreset('');
      onAdded();
    } catch (e) { setErr((e as Error).message); }
    finally { setBusy(false); }
  };

  return (
    <section className="cfg-section">
      <div className="cfg-section__label">Add a provider</div>
      <div className="cfg-card models-add">
        <div className="cfg-field">
          <label className="cfg-field__label" htmlFor="mdl-preset">Provider</label>
          <select id="mdl-preset" className="text-input" value={preset} onChange={(e) => { setPreset(e.target.value); setErr(null); setDone(null); }}>
            <option value="">Pick one…</option>
            {view.presets.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            <option value="other">Another server (any OpenAI-compatible address)</option>
          </select>
        </div>
        {preset !== '' && (custom || chosen) && (
          <>
            {custom && (
              <>
                <div className="cfg-field">
                  <label className="cfg-field__label" htmlFor="mdl-url">Base URL</label>
                  <input id="mdl-url" className="text-input" inputMode="url" autoCapitalize="off" autoCorrect="off" placeholder="https://api.example.com/v1" value={baseUrl} onChange={(e) => setBaseUrl(e.target.value)} />
                </div>
                <div className="cfg-field">
                  <label className="cfg-field__label" htmlFor="mdl-name">Name <span className="cfg-field__hint">(optional)</span></label>
                  <input id="mdl-name" className="text-input" value={name} maxLength={60} onChange={(e) => setName(e.target.value)} />
                </div>
              </>
            )}
            <div className="cfg-field">
              <label className="cfg-field__label" htmlFor="mdl-key">API key{!needKey || custom ? ' (only if it wants one)' : ''}</label>
              <input id="mdl-key" className="text-input" type="password" autoComplete="off" spellCheck={false} placeholder={chosen?.keyHint ? `Get one at ${chosen.keyHint}` : 'Paste a key'} value={key} onChange={(e) => setKey(e.target.value)} />
              <div className="cfg-field__hint">Kept in your own home, readable only by you. It is never sent back to this page.</div>
            </div>
            {err && <div className="cfg-error">{err}</div>}
            {done && <div className="cfg-field__hint models-done">{done}</div>}
            <div><button type="button" className="cfg-btn cfg-btn--primary" disabled={!canAdd} onClick={add}>{busy ? 'Looking…' : 'Add and look for its models'}</button></div>
          </>
        )}
        {preset === '' && done && <div className="cfg-field__hint models-done">{done}</div>}
      </div>
    </section>
  );
}

export function ModelsSection() {
  const [view, setView] = useState<ModelsView | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [agentId, setAgentId] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const botsInStore = useStore((s) => s.bots);

  const load = useCallback(() => {
    setError(null);
    configApi.models().then((v) => { setView(v); setAgentId((cur) => cur ?? v.bots.find((b) => b.primary)?.id ?? v.bots[0]?.id ?? null); })
      .catch((e: Error) => setError(e.message));
  }, []);
  useEffect(() => { load(); }, [load]);

  const agent = view?.bots.find((b) => b.id === agentId) ?? null;
  const total = useMemo(() => view?.providers.reduce((n, p) => n + p.models.filter((m) => m.allowed).length, 0) ?? 0, [view]);

  const use = async (providerId: string, model: string) => {
    if (!agent) return;
    setBusy(`${providerId}/${model}`); setNote(null);
    try {
      await configApi.useModel(agent.id, { providerId, model });
      setNote(`${agent.name} now uses ${model}. Its gateway was reloaded; the next message goes through the new model.`);
      load();
    } catch (e) { setNote((e as Error).message); }
    finally { setBusy(null); }
  };
  const remove = async (id: string) => { try { await configApi.removeProvider(id); load(); } catch (e) { setNote((e as Error).message); } };

  return (
    <>
      <div className="app-settings__head">
        <h1>Models</h1>
        <p>Whatever providers you already have are found here. Pick a model for each agent; each can have its own.</p>
      </div>

      {error && <div className="cfg-error">{error} <button type="button" className="cfg-btn cfg-btn--secondary" onClick={load}>Look again</button></div>}
      {!view && !error && <div className="cfg-empty cfg-empty--flat">Looking for your providers…</div>}

      {view && (
        <>
          {view.policed && (
            <div className="cfg-field__hint models-policy" role="note">
              Your fleet has an allow-list, so only the models it allows can be chosen. The others are greyed out.
            </div>
          )}

          {view.bots.length > 1 && (
            <section className="cfg-section">
              <div className="cfg-section__label">Choosing for</div>
              <div className="cfg-seg" role="radiogroup" aria-label="Agent">
                {view.bots.map((b) => (
                  <button key={b.id} type="button" role="radio" aria-checked={b.id === agentId} className={b.id === agentId ? 'is-active' : ''} onClick={() => { setAgentId(b.id); setNote(null); }}>
                    {botsInStore.find((x) => x.id === b.id)?.name ?? b.name}
                  </button>
                ))}
              </div>
            </section>
          )}

          {agent && (
            <div className="cfg-field__hint models-now">
              {agent.name} uses <strong>{agent.model ?? 'the model its own setup gave it'}</strong>
              {agent.providerId ? ` (${agent.providerId})` : ''}.
            </div>
          )}
          {note && <div className="cfg-field__hint models-done" role="status">{note}</div>}

          {total > 12 && (
            <input className="text-input models-search" type="search" placeholder={`Search ${total} models`} value={query} onChange={(e) => setQuery(e.target.value)} aria-label="Search models" />
          )}

          {view.providers.length === 0 && (
            <div className="cfg-empty">No provider found on this computer yet. Add one below — pick OpenRouter, paste a key, and you are done.</div>
          )}
          {agent && view.providers.map((p) => (
            <ProviderCard key={p.id} p={p} agent={agent} current={{ providerId: agent.providerId, model: agent.model }} busy={busy} onUse={use} onRemove={remove} query={query} />
          ))}

          <AddProvider view={view} onAdded={load} />
        </>
      )}
    </>
  );
}

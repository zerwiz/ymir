import { useCallback, useEffect, useRef, useState } from 'react';
import type { Bot, EngineInfo, EngineProvider } from '@shared/types';
import { configApi, type ModelsView } from '../lib/configApi';
import { useStore } from '../store';
import { Icon } from './Icon';
import { PickList } from './PickList';

const STATUS: Record<EngineInfo['status'], string> = { ready: 'ready', starting: 'starting', stopped: 'stopped', error: 'error' };

/** Connected providers first; otherwise the server's order. */
function sortProviders(list: EngineProvider[]): EngineProvider[] {
  return [...list].sort((a, b) => Number(b.connected) - Number(a.connected));
}

/**
 * "Engine" section of the details panel: which provider and model run this bot's agent, signing in to
 * a subscription, and the agent's status. Every call fails soft: if the engine endpoints are missing or
 * down, the section says so and the rest of the panel is unaffected.
 */
/** The catalog's providers of one kind: local (this machine or the fleet's rails) or online, those with a usable model first. */
function catProviders(v: ModelsView | null, where: 'local' | 'online') {
  // "local" is the house's own hardware: this machine's rail and the fleet's rails (tailnet, loopback, a LAN name)
  const own = (p: { local?: boolean; baseUrl: string }) => !!p.local || /\/\/(127\.0\.0\.1|localhost|[^/]*\.ts\.net|[^/.]+)(:\d+)?\//.test(p.baseUrl);
  return (v?.providers ?? []).filter((p) => own(p) === (where === 'local'))
    .sort((a, b) => Number(b.models.some((m) => m.allowed)) - Number(a.models.some((m) => m.allowed)));
}

export function EngineSettings({ bot }: { bot: Bot }) {
  const viewerOpen = useStore((s) => s.viewerOpen);
  const set = useStore((s) => s.set);
  const [engine, setEngine] = useState<EngineInfo | null>(null);
  const [phase, setPhase] = useState<'loading' | 'ok' | 'unavailable'>('loading');
  const [provider, setProvider] = useState('');
  const [, setModel] = useState('');   // kept in step with the engine; the chooser below edits the catalog choice
  const [busy, setBusy] = useState<'save' | 'signin' | 'restart' | 'screen' | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [signingIn, setSigningIn] = useState(false);
  const dirty = useRef(false);
  const botId = bot.id;
  // The house's catalog (plan 275, 2026-11-13): every provider found on this machine, local or online, each with
  // its whole model list — chosen from dropdowns, never typed. Saving writes the choice into the agent's Hermes home.
  const [catalog, setCatalog] = useState<ModelsView | null>(null);
  const [where, setWhere] = useState<'local' | 'online'>('local');
  const [catProvider, setCatProvider] = useState('');
  const [catModel, setCatModel] = useState('');
  useEffect(() => {
    let alive = true;
    configApi.models().then((v) => {
      if (!alive) return;
      setCatalog(v);
      const mine = v.providers.find((p) => p.id === bot.provider) ?? v.providers.find((p) => p.models.some((m) => m.id === bot.model));
      if (mine) { setWhere(catProviders(v, 'local').some((p) => p.id === mine.id) ? 'local' : 'online'); setCatProvider(mine.id); setCatModel(bot.model ?? ''); }
    }).catch(() => {});
    return () => { alive = false; };
  }, [botId]);

  const apply = useCallback((e: EngineInfo, keepDraft = false) => {
    setEngine(e); setPhase('ok');
    if (!keepDraft || !dirty.current) { dirty.current = false; setProvider(e.provider ?? ''); setModel(e.model ?? ''); }
    // Keep the bot's model label in step without waiting for the server's `bot` event.
    useStore.setState((s) => ({ bots: s.bots.map((b) => (b.id === e.botId && (b.model !== e.model || b.provider !== e.provider) ? { ...b, model: e.model, provider: e.provider } : b)) }));
  }, []);

  /** Quiet refreshes keep what is on screen if the call fails. */
  const load = useCallback((quiet = false) => {
    let alive = true;
    if (!quiet) setPhase('loading');
    configApi.engine(botId)
      .then((r) => { if (alive && r?.engine) apply(r.engine, quiet); else if (alive && !quiet) setPhase('unavailable'); })
      .catch(() => { if (alive && !quiet) setPhase('unavailable'); });
    return () => { alive = false; };
  }, [botId, apply]);

  useEffect(() => { dirty.current = false; setEngine(null); setNote(null); setSigningIn(false); return load(); }, [load]);

  // The agent takes a moment to come up after a change or a restart.
  const starting = engine?.status === 'starting';
  useEffect(() => {
    if (!starting) return;
    const t = setInterval(() => load(true), 3000);
    return () => clearInterval(t);
  }, [starting, load]);

  // Signing in happens on the bot's computer. Check while that view is open, and once more when it closes.
  useEffect(() => {
    if (!signingIn) return;
    if (!viewerOpen) { setSigningIn(false); load(true); return; }
    const t = setInterval(() => load(true), 5000);
    return () => clearInterval(t);
  }, [signingIn, viewerOpen, load]);

  if (phase !== 'ok' || !engine) {
    return (
      <div className="panel-card">
        <div className="panel-empty engine__empty">
          {phase === 'loading' ? 'Checking…' : (
            <>
              <span>The engine is silent</span>
              <button type="button" className="link-btn link-btn--small" onClick={() => load()}>Try again</button>
            </>
          )}
        </div>
      </div>
    );
  }

  const providers = sortProviders(engine.providers ?? []);
  const selected = providers.find((p) => p.id === provider) ?? null;
  const openSubscriptions = providers.filter((p) => p.kind === 'subscription' && !p.connected);
  const signInTo = selected && selected.kind === 'subscription' && !selected.connected ? selected : null;

  const signIn = async () => {
    if (busy) return;
    setBusy('signin'); setNote(null);
    try {
      await configApi.engineLogin(botId, signInTo?.id);
      // The sign-in runs in a terminal on the bot's screen, so take the person there with the mouse and keyboard.
      set({ viewerOpen: true, viewerMode: 'control', viewerHint: `Finish signing in on ${bot.name}’s computer, then hand back.` });
      setSigningIn(true);
    } catch (e) { setNote(`Couldn’t start sign-in: ${(e as Error).message || 'the engine did not answer'}`); }
    finally { setBusy(null); }
  };

  const restart = async () => {
    if (busy) return;
    setBusy('restart'); setNote(null);
    try { const r = await configApi.restartEngine(botId); apply(r.engine, true); }
    catch (e) { setNote(`Couldn’t restart: ${(e as Error).message || 'the engine did not answer'}`); }
    finally { setBusy(null); }
  };

  const useThisScreen = async () => {
    if (busy) return;
    setBusy('screen'); setNote(null);
    try { const r = await configApi.stopOwnScreen(botId); apply(r.engine, true); }
    catch (e) { setNote(`Couldn’t switch screens: ${(e as Error).message || 'the engine did not answer'}`); }
    finally { setBusy(null); }
  };

  return (
    <div className="panel-card engine">
      <div className="engine__where" role="radiogroup" aria-label="Where it thinks">
        {(['local', 'online'] as const).map((w) => (
          <button key={w} type="button" role="radio" aria-checked={where === w} className={`engine__where-btn${where === w ? ' is-on' : ''}`}
            onClick={() => {
              if (where === w) return;
              setWhere(w); setNote(null);
              const first = catProviders(catalog, w)[0];
              setCatProvider(first?.id ?? ''); setCatModel(first?.models.find((m) => m.allowed)?.id ?? '');
            }}>
            {w === 'local' ? 'Local' : 'Online'}
            <span>{w === 'local' ? 'on this machine or the fleet' : 'a hosted provider'}</span>
          </button>
        ))}
      </div>
      <div className="panel-row panel-row--setting">
        <span>Provider</span>
        <PickList label="Provider" value={catProvider} placeholder={catalog ? 'None found' : 'Looking…'}
          options={catProviders(catalog, where).map((p) => ({ value: p.id, label: p.name, hint: `${p.models.filter((m) => m.allowed).length} models` }))}
          onPick={(id) => { setNote(null); setCatProvider(id); setCatModel(catalog?.providers.find((p) => p.id === id)?.models.find((m) => m.allowed)?.id ?? ''); }} />
      </div>
      <div className="panel-row panel-row--setting">
        <span>Model</span>
        <PickList label="Model" value={catModel} placeholder="Choose a provider"
          options={(catalog?.providers.find((p) => p.id === catProvider)?.models ?? []).filter((m) => m.allowed).map((m) => ({ value: m.id, label: m.id }))}
          onPick={(m) => { setNote(null); setCatModel(m); }} />
      </div>
      {(() => {
        const held = (catalog?.providers.find((p) => p.id === catProvider)?.models ?? []).filter((m) => !m.allowed).length;
        return held ? <div className="engine__held">{held} more from this provider are held back by the fleet's allow-list.</div> : null;
      })()}
      <div className="engine__actions">
        <button type="button" className="btn btn--sm btn--bot" disabled={!catModel || busy === 'save' || (catModel === (engine.model ?? '') && catProvider === (bot.provider ?? ''))}
          onClick={async () => {
            if (!catProvider || !catModel || busy) return;
            setBusy('save'); setNote(null);
            try { await configApi.chooseModel(botId, catProvider, catModel); dirty.current = false; load(true); setNote(null); }
            catch (e) { setNote(`Couldn’t save: ${(e as Error).message || 'the engine did not answer'}`); }
            finally { setBusy(null); }
          }}>{busy === 'save' ? 'Saving…' : 'Save'}</button>
        <span className="engine__now">Now: {engine.model ?? 'none'}</span>
      </div>
      {(signInTo || openSubscriptions.length > 0) && (
        <button type="button" className="panel-row panel-row--action engine__signin" onClick={signIn} disabled={busy === 'signin'}>
          <Icon name="monitor" size={14} opacity={0.56} />
          {busy === 'signin' ? 'Opening sign-in…' : signInTo ? `Sign in to ${signInTo.name}…` : 'Sign in to a subscription…'}
        </button>
      )}
      {engine.ownScreen && (
        <div className="engine__notice">
          <span>{bot.name} also has a private screen of its own switched on. Desktop work it does there (clicking around apps) will not show on the screen here.</span>
          <button type="button" className="link-btn link-btn--small" onClick={useThisScreen} disabled={busy === 'screen'}>{busy === 'screen' ? 'Switching…' : 'Use this screen'}</button>
        </div>
      )}
      {note && <div className="voice-error" role="alert">{note}</div>}
      <div className="engine__meta">
        <span className={`engine__state is-${engine.status}`} title={engine.version ? `Hermes ${engine.version}` : undefined}>
          <i aria-hidden />
          Hermes · profile {engine.profile} · {STATUS[engine.status] ?? engine.status}
        </span>
        {(engine.status === 'error' || engine.status === 'stopped') && (
          <button type="button" className="link-btn link-btn--small" onClick={restart} disabled={busy === 'restart'}>{busy === 'restart' ? 'Restarting…' : 'Restart agent'}</button>
        )}
      </div>
      {engine.status === 'error' && engine.error && <div className="engine__error">{engine.error}</div>}
    </div>
  );
}

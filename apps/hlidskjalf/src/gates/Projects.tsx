import { Fragment, useEffect, useMemo, useRef, useState } from 'react';
import { desktopHeaders } from '../services/api';
import { Worktrees } from './Worktrees';

type WT = { id: string; branch: string; path: string; head: string; agent: string; stale: boolean; reason: string };
type Kit = { seated: boolean; reporting: boolean; version?: string; current?: string; behind?: boolean; guards?: string; update?: string } | null;
type Where = {
  seat: string; reachable: boolean; reason?: string; path?: string; worktrees: WT[]; worktree_count: number;
  stale_count: number; kit: Kit; last_activity?: number; disk_free_gb?: number;
};
type PR = { number: number; title: string; branch: string; ci: string; review: string; draft: boolean; url: string };
export type Project = {
  id: string; name: string; realm: string; visibility: string; remote: string; where: Where[]; prs: PR[];
  pr_count: number; ci: string; health: string[]; next: string[];
  sessions?: { sessions: number; by_tool: Record<string, number>; by_seat: Record<string, number>; updates: { action: string; text: string; tool: string; session: string }[] } | null;
};
type Doc = { count: number; projects: Project[]; error?: string };

const th = { textAlign: 'left' as const, borderBottom: '1px solid #333', padding: 6, whiteSpace: 'nowrap' as const };
const td = { padding: 6, verticalAlign: 'top' as const };
const nw = { whiteSpace: 'nowrap' as const };
const ciColor = (ci: string) => (ci === 'red' ? 'crimson' : ci === 'green' ? 'seagreen' : undefined);

/** Below ~700px a table is unusable: render one card per project instead. */
function useNarrow(px = 700) {
  const q = `(max-width: ${px}px)`;
  const [n, setN] = useState(() => (typeof window !== 'undefined' && window.matchMedia ? window.matchMedia(q).matches : false));
  useEffect(() => {
    if (!window.matchMedia) return;
    const m = window.matchMedia(q);
    const f = () => setN(m.matches);
    f(); m.addEventListener('change', f);
    return () => m.removeEventListener('change', f);
  }, [q]);
  return n;
}

export function kitLabel(k: Kit): string {
  if (!k) return '—';
  if (!k.reporting) return 'seated, not reporting';
  return k.behind ? `kit ${k.version} → ${k.current}` : `kit ${k.version}`;
}
export const sum = (p: Project, f: (w: Where) => number) => p.where.reduce((n, w) => n + f(w), 0);

export function Projects() {
  const [doc, setDoc] = useState<Doc | null>(null);
  const [err, setErr] = useState('');
  const got = useRef(false);   // a later failed refresh must not hide rows already shown
  const [open, setOpen] = useState<string>('');
  const [seat, setSeat] = useState('');
  const [realm, setRealm] = useState('');
  const [hasPrs, setHasPrs] = useState(false);
  const [red, setRed] = useState(false);
  const [stale, setStale] = useState(false);
  const [fleet, setFleet] = useState(false);
  const narrow = useNarrow();

  useEffect(() => {
    let live = true;
    const load = () => fetch(fleet ? '/api/projects?fleet=1' : '/api/projects', { credentials: 'include', headers: desktopHeaders() })
      .then((r) => r.json())
      .then((d: Doc) => { if (live) { got.current = true; setDoc(d); setErr(d.error ?? ''); } })
      .catch((e) => { if (live && !got.current) setErr(String(e)); });
    load();
    const t = setInterval(load, 60_000);
    return () => { live = false; clearInterval(t); };
  }, [fleet]);

  const all = doc?.projects ?? [];
  const seats = useMemo(() => [...new Set(all.flatMap((p) => p.where.map((w) => w.seat)))].sort(), [all]);
  const realms = useMemo(() => [...new Set(all.map((p) => p.realm).filter(Boolean))].sort(), [all]);
  const rows = all.filter((p) =>
    (!seat || p.where.some((w) => w.seat === seat)) && (!realm || p.realm === realm) &&
    (!hasPrs || p.pr_count > 0) && (!red || p.ci === 'red') && (!stale || sum(p, (w) => w.stale_count) > 0));

  return (
    <div style={{ padding: 20 }}>
      <h2 style={{ margin: '0 0 12px' }}>Projects</h2>
      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginBottom: 12, fontSize: 13 }}>
        <select aria-label="seat" value={seat} onChange={(e) => setSeat(e.target.value)}>
          <option value="">all seats</option>{seats.map((s) => <option key={s}>{s}</option>)}
        </select>
        <select aria-label="realm" value={realm} onChange={(e) => setRealm(e.target.value)}>
          <option value="">all realms</option>{realms.map((s) => <option key={s}>{s}</option>)}
        </select>
        <label><input type="checkbox" checked={hasPrs} onChange={(e) => setHasPrs(e.target.checked)} /> has PRs</label>
        <label><input type="checkbox" checked={red} onChange={(e) => setRed(e.target.checked)} /> red</label>
        <label title="ask the other seats over the ring"><input type="checkbox" checked={fleet} onChange={(e) => setFleet(e.target.checked)} /> fleet</label>
        <label><input type="checkbox" checked={stale} onChange={(e) => setStale(e.target.checked)} /> stale</label>
      </div>
      {err && <p style={{ color: 'crimson' }}>{err}</p>}
      {doc && all.length === 0 && (
        <p style={{ opacity: 0.8 }}>
          No projects yet. Add one with <code>ymir projects add &lt;repo-url|path&gt;</code>; add{' '}
          <code>--kit --report</code> to seat the collaboration kit so the repo reports its state here.
        </p>
      )}
      {narrow ? (
        <div style={{ display: 'grid', gap: 10 }}>
          {rows.map((p) => {
            const kit = p.where.map((w) => w.kit).find(Boolean) ?? null;
            const stale = sum(p, (w) => w.stale_count);
            const f = (k: string, v: React.ReactNode) => <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}><span style={{ opacity: 0.6 }}>{k}</span><span style={{ textAlign: 'right' }}>{v}</span></div>;
            return (
              <div key={p.id} style={{ border: '1px solid #333', borderRadius: 8, padding: 12, fontSize: 13, display: 'grid', gap: 4 }}>
                <div><b>{p.name}</b> <span style={{ opacity: 0.6 }}>{p.realm}</span></div>
                {f('seat', p.where.length ? p.where.map((w) => <span key={w.seat} style={nw}>{w.seat}{w.reachable ? '' : ' (unreachable)'} </span>) : '—')}
                {f('worktrees', `${sum(p, (w) => w.worktree_count)}${stale > 0 ? ` · ${stale} stale` : ''}`)}
                {f('PRs', p.pr_count)}
                {f('CI', <span style={{ color: ciColor(p.ci) }}>{p.ci}</span>)}
                {f('kit', kitLabel(kit))}
                {f('sessions', p.sessions ? `${p.sessions.sessions} · ${Object.entries(p.sessions.by_tool).map(([t, n]) => `${t} ${n}`).join(', ')}` : '—')}
                {f('health', p.health.length ? p.health.join('; ') : 'ok')}
                {p.next.map((n) => <div key={n} style={{ overflowWrap: 'anywhere' }}><code>{n}</code></div>)}
              </div>
            );
          })}
        </div>
      ) : (
      <div style={{ overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13, minWidth: 640 }}>
          <thead><tr>{['project', 'seat', 'trees', 'PRs', 'CI', 'kit', 'sessions', 'health'].map((h) => <th key={h} style={th}>{h}</th>)}</tr></thead>
          <tbody>
            {rows.map((p) => {
              const kit = p.where.map((w) => w.kit).find(Boolean) ?? null;
              const isOpen = open === p.id;
              return (
                <Fragment key={p.id}>
                  <tr key={p.id} onClick={() => setOpen(isOpen ? '' : p.id)} style={{ cursor: 'pointer' }}>
                    <td style={td}><b>{p.name}</b><br /><span style={{ opacity: 0.6 }}>{p.realm}</span></td>
                    <td style={td}>{p.where.map((w) => <div key={w.seat} style={nw}>{w.seat}{w.reachable ? '' : ' (unreachable)'}</div>)}</td>
                    <td style={{ ...td, ...nw }} title="worktrees">{sum(p, (w) => w.worktree_count)}{sum(p, (w) => w.stale_count) > 0 && ` · ${sum(p, (w) => w.stale_count)} stale`}</td>
                    <td style={td}>{p.pr_count}</td>
                    <td style={{ ...td, ...nw, color: ciColor(p.ci) }}>{p.ci}</td>
                    <td style={td}>{kitLabel(kit)}</td>
                    <td style={td}>{p.sessions ? `${p.sessions.sessions} · ${Object.entries(p.sessions.by_tool).map(([t, n]) => `${t} ${n}`).join(', ')}` : '—'}</td>
                    <td style={td}>{p.health.length ? p.health.join('; ') : 'ok'}{p.next.map((n) => <div key={n}><code>{n}</code></div>)}</td>
                  </tr>
                  {isOpen && (
                    <tr key={p.id + ':open'}><td colSpan={8} style={{ ...td, background: 'rgba(127,127,127,0.08)' }}>
                      {(p.sessions?.updates ?? []).map((u) => (
                        <div key={u.session + u.text}><b>next:</b> {u.action} — {u.text} <span style={{ opacity: 0.6 }}>({u.tool})</span></div>
                      ))}
                      {p.prs.map((r) => (
                        <div key={r.number}>#{r.number} {r.title} — {r.ci} · {r.review}{r.draft ? ' · draft' : ''}</div>
                      ))}
                      {p.where.filter((w) => w.reachable && w.worktrees.length > 0).map((w) => (
                        <details key={w.seat} style={{ marginTop: 6 }}>
                          <summary>{w.seat}: {w.worktree_count} worktree(s) at {w.path}</summary>
                          <table style={{ fontSize: 12 }}><tbody>{w.worktrees.map((t) => (
                            <tr key={t.path}><td style={td}>{t.id}</td><td style={td}>{t.branch}</td><td style={td}>{t.agent}</td>
                              <td style={td}>{t.stale ? t.reason : ''}</td></tr>))}</tbody></table>
                        </details>
                      ))}
                    </td></tr>
                  )}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>
      )}
      <details style={{ marginTop: 20 }}><summary>This checkout's worktrees</summary><Worktrees /></details>
    </div>
  );
}

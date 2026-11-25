import { useEffect, useState } from 'react';
import { desktopHeaders } from '../services/api';

type S = { id: string; tool: string; seat: string; project: string; last: number; spans: number; errors: number; title: string; outcome: string; summary: string; confidential: number };
type D = { signature: string; count: number; sample: string; sessions: { id: string; tool: string; seat: string; project: string; title: string }[]; tools: string[]; projects: string[] };

function useIndex<T>(path: string, key: string, fleet: boolean) {
  const [rows, setRows] = useState<T[]>([]);
  const [err, setErr] = useState('');
  useEffect(() => {
    let live = true;
    fetch(`${path}${fleet ? '?fleet=1' : ''}`, { credentials: 'include', headers: desktopHeaders() })
      .then((r) => r.json())
      .then((d) => { if (live) { setRows(d[key] ?? []); setErr(d.error ?? ''); } })
      .catch((e) => { if (live) setErr(String(e)); });
    return () => { live = false; };
  }, [path, key, fleet]);
  return { rows, err };
}

type U = { project: string; session: string; action: string; text: string; tool: string; seat: string };

/** The next updates per project, each naming the session it came from (plan 368). */
function NextUpdates() {
  const { rows } = useIndex<U>('/api/sessions/updates', 'updates', false);
  if (rows.length === 0) return null;
  const by: Record<string, U[]> = {};
  rows.forEach((u) => { (by[u.project || '—'] ??= []).push(u); });
  return (
    <div style={{ padding: '10px 12px', borderBottom: '1px solid var(--ymir-line, #333)', fontSize: 13 }}>
      <b>Next updates</b>
      {Object.entries(by).slice(0, 12).map(([proj, us]) => (
        <div key={proj} style={{ marginTop: 6 }}>
          <span style={{ fontWeight: 600 }}>{proj}</span>
          {us.slice(0, 3).map((u) => (
            <div key={u.session + u.text} className="dim" style={{ paddingLeft: 10 }}>{u.action} — {u.text} <span style={{ opacity: 0.6 }}>({u.tool})</span></div>
          ))}
        </div>
      ))}
    </div>
  );
}

const when = (t: number) => (t ? new Date(t * 1000).toISOString().slice(0, 16).replace('T', ' ') : '—');

/** Every agent session on this machine, from every tool (plan 368). Fleet is an opt-in filter. */
export function AllSessions() {
  const [fleet, setFleet] = useState(false);
  const [tool, setTool] = useState('');
  const { rows, err } = useIndex<S>('/api/sessions/index', 'sessions', fleet);
  const tools = [...new Set(rows.map((r) => r.tool))].sort();
  const shown = rows.filter((r) => !tool || r.tool === tool);
  return (
    <section className="panel" style={{ marginTop: 0 }}>
      <div className="panel-head">
        <div className="panel-title"><span className="glyph" aria-hidden="true">ᛋ</span> Sessions · every tool (Claude Code, pi, Codex, Hermes, opencode)</div>
        <div className="row" style={{ gap: 8, fontSize: 13 }}>
          <select aria-label="tool" value={tool} onChange={(e) => setTool(e.target.value)}>
            <option value="">all tools</option>{tools.map((t) => <option key={t}>{t}</option>)}
          </select>
          <label title="ask the other seats; this machine builds the answer"><input type="checkbox" checked={fleet} onChange={(e) => setFleet(e.target.checked)} /> fleet</label>
        </div>
      </div>
      <div className="panel-body flush" style={{ overflowX: 'auto' }}>
        <NextUpdates />
        {err && <p className="dim" style={{ padding: 12 }}>{err}</p>}
        {shown.length === 0 && !err && <div className="empty" style={{ padding: 24 }}><p>No sessions indexed yet. Run <code>ymir sessions scan</code>.</p></div>}
        {shown.length > 0 && (
          <table className="data-table">
            <thead><tr><th>Tool</th><th>Seat</th><th>Project</th><th>Last</th><th>Spans</th><th>Errors</th><th>Session</th></tr></thead>
            <tbody>
              {shown.slice(0, 200).map((r) => (
                <tr key={`${r.seat}:${r.id}`}>
                  <td className="mono">{r.tool}</td><td className="muted">{r.seat}</td><td>{r.project || '—'}</td>
                  <td className="muted">{when(r.last)}</td><td className="num">{r.spans}</td>
                  <td className="num" style={{ color: r.errors ? 'var(--ymir-danger)' : undefined }}>{r.errors}</td>
                  <td className="dim" style={{ maxWidth: 320, overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.confidential ? '(confidential — counted only)' : r.summary || r.title}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}

/** The same failure across tools, once, with every session it hit (plan 368). */
export function AllDecisions() {
  const { rows, err } = useIndex<D>('/api/sessions/decisions', 'decisions', false);
  return (
    <section className="panel" style={{ marginTop: 'var(--ymir-space-4)' }}>
      <div className="panel-head"><div className="panel-title"><span className="glyph" aria-hidden="true">ᚦ</span> Failures across every tool</div></div>
      <div className="panel-body flush" style={{ overflowX: 'auto' }}>
        {err && <p className="dim" style={{ padding: 12 }}>{err}</p>}
        {rows.length === 0 && !err && <div className="empty" style={{ padding: 24 }}><p>No failures indexed. Run <code>ymir sessions scan</code>.</p></div>}
        {rows.length > 0 && (
          <table className="data-table">
            <thead><tr><th>Failure</th><th>Hits</th><th>Sessions</th><th>Tools</th><th>Projects</th></tr></thead>
            <tbody>
              {rows.slice(0, 50).map((d) => (
                <tr key={d.signature}>
                  <td className="mono" style={{ maxWidth: 380, overflow: 'hidden', textOverflow: 'ellipsis' }} title={d.sample}>{d.signature}</td>
                  <td className="num">{d.count}</td>
                  <td title={d.sessions.map((s) => `${s.tool}:${s.id}`).join('\n')}>{d.sessions.length}</td>
                  <td className="muted">{d.tools.join(', ')}</td><td className="muted">{d.projects.join(', ')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}

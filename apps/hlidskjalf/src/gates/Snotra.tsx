import { useEffect, useMemo, useState } from 'react';
import { MetricTile } from '../components/MetricTile';

/**
 * Snotra — the meeting record in the gate (plan 93).
 *
 * The shelf is read; the record is read; the two mutations are explicit and
 * audited. Nothing here edits a rendered record, and sending is the approval.
 */

type Participant = { name: string; email: string | null };
type Meeting = {
  id: string; title: string; started_at: string | null; workspace: string;
  source: string; state: string; decisions: number; actions: number;
  participants: Participant[];
};
type Decision = { decision_id: string; statement: string; decided_by: string; evidence?: { timestamp: string; quote: string } };
type Action = { action_id: string; deliverable: string; owner: string; due_at: string | null; status: string; dependency?: string | null };
type Detail = Meeting & { record: string | null; decisions: Decision[]; actions: Action[] };

type Tab = 'record' | 'decisions' | 'actions' | 'people';

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, { credentials: 'include', headers: { 'Content-Type': 'application/json' }, ...init });
  const data = (await res.json().catch(() => ({}))) as T & { error?: string };
  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}

const stateTone = (s: string) =>
  s === 'dispatched' ? 'var(--ymir-ok)' : s === 'recorded' ? 'var(--ymir-accent, #c9973f)' : s === 'transcribed' ? 'var(--ymir-warn, #b45309)' : 'var(--ymir-muted, #8a8f98)';

export function Snotra() {
  const [rows, setRows] = useState<Meeting[] | null>(null);
  const [lane, setLane] = useState<'all' | 'work' | 'personal'>('all');
  const [openId, setOpenId] = useState<string | null>(null);
  const [detail, setDetail] = useState<Detail | null>(null);
  const [tab, setTab] = useState<Tab>('record');
  const [draftId, setDraftId] = useState<string | null>(null);
  const [msg, setMsg] = useState('');
  const [busy, setBusy] = useState(false);

  async function load() {
    try { setRows((await api<{ meetings: Meeting[] }>('/api/snotra/meetings')).meetings); }
    catch (e) { setRows([]); setMsg(String((e as Error).message)); }
  }
  useEffect(() => { void load(); }, []);

  async function open(id: string) {
    setOpenId(id); setDetail(null); setDraftId(null); setMsg(''); setTab('record');
    try { setDetail(await api<Detail>(`/api/snotra/meeting?id=${encodeURIComponent(id)}`)); }
    catch (e) { setMsg(String((e as Error).message)); }
  }

  async function prepare(id: string) {
    setBusy(true); setMsg('');
    try {
      const d = await api<{ draftId: string }>('/api/snotra/draft', { method: 'POST', body: JSON.stringify({ id }) });
      setDraftId(d.draftId); setMsg(`Draft ${d.draftId} prepared — review, then approve.`);
    } catch (e) { setMsg(String((e as Error).message)); }
    finally { setBusy(false); }
  }

  async function approveSend() {
    if (!draftId) return;
    setBusy(true); setMsg('');
    try {
      const d = await api<{ sent: string }>('/api/snotra/send', { method: 'POST', body: JSON.stringify({ draftId }) });
      setMsg(`Sent — Gmail message ${d.sent}.`); setDraftId(null); void load();
    } catch (e) { setMsg(String((e as Error).message)); }
    finally { setBusy(false); }
  }

  const visible = useMemo(() => (rows ?? []).filter((r) => lane === 'all' || r.workspace === lane), [rows, lane]);
  const unresolved = visible.reduce((n, r) => n + r.participants.filter((p) => !p.email).length, 0);

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Snotra — Meetings</h1>
          <p className="stage-deck">The record · prepare · approve · send · no rendered record is edited here</p>
        </div>
        <button className="btn btn-sm" onClick={() => void load()}>Refresh</button>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Meetings" value={visible.length} delta="on the shelf" />
        <MetricTile label="Decisions" value={visible.reduce((n, r) => n + r.decisions, 0)} delta="with evidence" />
        <MetricTile label="Actions" value={visible.reduce((n, r) => n + r.actions, 0)} delta="one owner each" />
        <MetricTile label="Unresolved" value={unresolved} tone={unresolved ? 'var(--ymir-warn)' : undefined} delta="addresses" />
      </div>

      {msg && (
        <div className="panel" style={{ marginBottom: 'var(--ymir-space-4)' }}>
          <div className="panel-body"><p style={{ margin: 0 }}>{msg}</p></div>
        </div>
      )}

      <div className="chips" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        {(['all', 'work', 'personal'] as const).map((l) => (
          <button key={l} className={`chip${lane === l ? ' on' : ''}`} onClick={() => setLane(l)}>{l}</button>
        ))}
      </div>

      <div className="gate-grid cols-2">
        <div className="panel">
          <div className="panel-body">
            <h2 style={{ marginTop: 0 }}>Shelf</h2>
            {rows === null ? <p className="muted">reading the shelf…</p>
              : visible.length === 0 ? <p className="muted">No meeting recorded yet — run the pipeline on a transcript.</p>
              : (
                <table className="data-table">
                  <thead><tr><th>Date</th><th>Meeting</th><th>Lane</th><th>State</th><th>Dec</th><th>Act</th><th /></tr></thead>
                  <tbody>
                    {visible.map((r) => (
                      <tr key={r.id} onClick={() => void open(r.id)} style={{ cursor: 'pointer', background: r.id === openId ? 'var(--ymir-row, rgba(255,255,255,.04))' : undefined }}>
                        <td>{(r.started_at ?? '').slice(0, 10)}</td>
                        <td>{r.title}</td>
                        <td>{r.workspace}</td>
                        <td><span className="dot" style={{ background: stateTone(r.state), display: 'inline-block', width: 7, height: 7, borderRadius: 99, marginRight: 6 }} />{r.state}</td>
                        <td>{r.decisions}</td>
                        <td>{r.actions}</td>
                        <td><button className="btn btn-sm" onClick={(e) => { e.stopPropagation(); void open(r.id); }}>Open</button></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
          </div>
        </div>

        <div className="panel">
          <div className="panel-body">
            {!detail ? (
              <p className="muted">Choose a meeting to open its record.</p>
            ) : (
              <>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, alignItems: 'start' }}>
                  <div>
                    <h2 style={{ margin: 0 }}>{detail.title}</h2>
                    <p className="muted" style={{ margin: '4px 0 0' }}>{detail.started_at} · {detail.source} · {detail.state}</p>
                  </div>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button className="btn btn-sm" disabled={busy} onClick={() => void prepare(detail.id)}>Prepare draft</button>
                    <button className="btn btn-primary btn-sm" disabled={busy || !draftId} onClick={() => void approveSend()}>Approve &amp; send</button>
                  </div>
                </div>

                <div className="chips" style={{ margin: '12px 0' }}>
                  {(['record', 'decisions', 'actions', 'people'] as Tab[]).map((t) => (
                    <button key={t} className={`chip${tab === t ? ' on' : ''}`} onClick={() => setTab(t)}>{t}</button>
                  ))}
                </div>

                {tab === 'record' && <pre style={{ whiteSpace: 'pre-wrap', maxHeight: 420, overflow: 'auto', fontSize: 12 }}>{detail.record ?? 'no record rendered yet'}</pre>}

                {tab === 'decisions' && (detail.decisions.length === 0 ? <p className="muted">No decisions.</p> : detail.decisions.map((d) => (
                  <div key={d.decision_id} style={{ marginBottom: 12 }}>
                    <strong>{d.decision_id}</strong> — {d.statement}
                    <div className="muted" style={{ fontSize: 12 }}>{d.decided_by}{d.evidence ? ` · [${d.evidence.timestamp}] “${d.evidence.quote.slice(0, 160)}”` : ''}</div>
                  </div>
                )))}

                {tab === 'actions' && (detail.actions.length === 0 ? <p className="muted">No actions.</p> : (
                  <table className="data-table">
                    <thead><tr><th>ID</th><th>Action</th><th>Owner</th><th>Due</th></tr></thead>
                    <tbody>{detail.actions.map((a) => (
                      <tr key={a.action_id}><td>{a.action_id.slice(-2)}</td><td>{a.deliverable}</td><td>{a.owner}</td><td>{a.due_at ?? 'unresolved'}</td></tr>
                    ))}</tbody>
                  </table>
                ))}

                {tab === 'people' && (
                  <table className="data-table">
                    <thead><tr><th>Participant</th><th>Email</th></tr></thead>
                    <tbody>{detail.participants.map((p) => (
                      <tr key={p.name}><td>{p.name}</td><td>{p.email ?? <em style={{ color: 'var(--ymir-warn)' }}>unresolved — blocks send</em>}</td></tr>
                    ))}</tbody>
                  </table>
                )}

                {draftId && <p className="muted" style={{ marginTop: 12 }}>Draft {draftId} — the next click sends it, to every addressed participant.</p>}
              </>
            )}
          </div>
        </div>
      </div>
    </>
  );
}

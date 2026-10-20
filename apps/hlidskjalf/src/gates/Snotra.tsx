import { useEffect, useState } from 'react';

/**
 * Snotra — the meeting record in the gate (plan 93).
 *
 * Read the shelf; open one record; prepare the follow-up draft; approve and send.
 * Nothing here edits a record. The two mutations call the Snotra doors and show
 * their answer — no optimistic UI, no silent send.
 */

type Meeting = {
  id: string;
  title: string;
  started_at: string | null;
  workspace: string;
  source: string;
  state: string;
  decisions: number;
  actions: number;
  participants: { name: string; email: string | null }[];
};

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, {
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    ...init,
  });
  const data = (await res.json().catch(() => ({}))) as T & { error?: string };
  if (!res.ok) throw new Error((data as { error?: string }).error || `HTTP ${res.status}`);
  return data;
}

export function Snotra() {
  const [rows, setRows] = useState<Meeting[] | null>(null);
  const [openId, setOpenId] = useState<string | null>(null);
  const [record, setRecord] = useState<string | null>(null);
  const [draftId, setDraftId] = useState<string | null>(null);
  const [msg, setMsg] = useState<string>('');
  const [busy, setBusy] = useState(false);

  async function load() {
    try {
      const d = await api<{ meetings: Meeting[] }>('/api/snotra/meetings');
      setRows(d.meetings);
    } catch (e) {
      setRows([]);
      setMsg(String((e as Error).message));
    }
  }
  useEffect(() => { void load(); }, []);

  async function open(id: string) {
    setOpenId(id); setRecord(null); setDraftId(null); setMsg('');
    try {
      const d = await api<Meeting & { record: string | null }>(`/api/snotra/meeting?id=${encodeURIComponent(id)}`);
      setRecord(d.record);
    } catch (e) { setMsg(String((e as Error).message)); }
  }

  async function prepare(id: string) {
    setBusy(true); setMsg('');
    try {
      const d = await api<{ draftId: string }>('/api/snotra/draft', { method: 'POST', body: JSON.stringify({ id }) });
      setDraftId(d.draftId); setMsg(`draft ${d.draftId} ready — review, then approve`);
    } catch (e) { setMsg(String((e as Error).message)); }
    finally { setBusy(false); }
  }

  async function approveSend() {
    if (!draftId) return;
    setBusy(true); setMsg('');
    try {
      const d = await api<{ sent: string }>('/api/snotra/send', { method: 'POST', body: JSON.stringify({ draftId }) });
      setMsg(`sent ${d.sent}`); setDraftId(null); void load();
    } catch (e) { setMsg(String((e as Error).message)); }
    finally { setBusy(false); }
  }

  const openRow = rows?.find((r) => r.id === openId);

  return (
    <div className="page">
      <header className="page-head">
        <h1>Snotra</h1>
        <p className="dim">The meeting record: read · prepare · approve · send. No record is edited here.</p>
      </header>

      {msg && <div className="notice">{msg}</div>}

      <div className="snotra-grid">
        <section className="panel">
          <h2>Meetings</h2>
          {rows === null ? (
            <p className="dim">reading the shelf…</p>
          ) : rows.length === 0 ? (
            <p className="dim">no meeting has been recorded yet — run the pipeline on a transcript.</p>
          ) : (
            <table className="table">
              <thead><tr><th>Date</th><th>Meeting</th><th>Lane</th><th>State</th><th>Dec · Act</th><th /></tr></thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id} className={r.id === openId ? 'sel' : ''}>
                    <td>{(r.started_at ?? '').slice(0, 10)}</td>
                    <td>{r.title}</td>
                    <td>{r.workspace}</td>
                    <td>{r.state}</td>
                    <td>{r.decisions} · {r.actions}</td>
                    <td><button onClick={() => void open(r.id)}>Open</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </section>

        {openRow && (
          <section className="panel">
            <h2>{openRow.title}</h2>
            <p className="dim">
              {openRow.started_at} · {openRow.source} · {openRow.state}
            </p>
            <h3>Participants</h3>
            <ul>
              {openRow.participants.map((p) => (
                <li key={p.name}>{p.name} — {p.email ?? <em>address unresolved</em>}</li>
              ))}
            </ul>
            <div className="actions">
              <button disabled={busy} onClick={() => void prepare(openRow.id)}>Prepare draft</button>
              <button disabled={busy || !draftId} onClick={() => void approveSend()}>Approve &amp; send</button>
            </div>
            {draftId && <p className="dim">draft {draftId} — sending is the approval</p>}
            <h3>Record</h3>
            <pre className="record-view">{record ?? 'no record rendered yet'}</pre>
          </section>
        )}
      </div>
    </div>
  );
}

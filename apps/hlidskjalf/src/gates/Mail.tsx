import { useCallback, useEffect, useState } from 'react';
import { gateApi, type MailQueue, type MailRow, type MailMessage } from '../services/api';
import { MetricTile } from '../components/MetricTile';

const COLUMNS: { key: keyof MailQueue['columns']; label: string; note: string }[] = [
  { key: 'needs_you', label: 'Needs you', note: 'judged · an action proposed · nothing sent' },
  { key: 'unsure', label: 'Unsure', note: 'low confidence, or a sender the book does not know' },
  { key: 'waiting', label: 'Waiting', note: 'outbound · no answer yet' },
  { key: 'done', label: 'Done today', note: 'recorded, or bulk mail that asked nobody anything' },
];

/**
 * Gná — the one mail desk (plan 116, phase P0).
 *
 * The gate is a front for `hodd/bin/gna-agent/gna_desk.py` on 127.0.0.1:8490; it
 * renders what that desk says and adds no judgement of its own. There is no send
 * button and no draft box here: the desk cannot send, and this page must not
 * pretend it could.
 */
export function Mail() {
  const [accounts, setAccounts] = useState<string[]>([]);
  const [account, setAccount] = useState('');
  const [hours, setHours] = useState(48);
  const [queue, setQueue] = useState<MailQueue | null>(null);
  const [open, setOpen] = useState<MailMessage | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const loadQueue = useCallback(
    async (who: string, window: number) => {
      if (!who) return;
      setBusy(true);
      try {
        const [q, accountsResp] = await Promise.all([gateApi.mailQueue(who, window), gateApi.mailAccounts()]);
        setQueue(q);
        setAccounts(accountsResp.accounts);
        setError('');
      } catch (e) {
        setQueue(null);
        setError((e as Error).message || 'the desk did not answer');
      } finally {
        setBusy(false);
      }
    },
    [],
  );

  useEffect(() => {
    (async () => {
      try {
        const { accounts: declared } = await gateApi.mailAccounts();
        setAccounts(declared);
        const first = declared[0] ?? '';
        setAccount(first);
        await loadQueue(first, hours);
      } catch (e) {
        setError((e as Error).message || 'the desk did not answer');
      }
    })();
  }, [hours, loadQueue]);

  async function openMessage(row: MailRow) {
    try {
      const full = await gateApi.mailMessage(row.account, row.id);
      setOpen(full);
    } catch (e) {
      setError((e as Error).message || 'that message could not be read');
    }
  }

  const counts = queue?.counts ?? { needs_you: 0, unsure: 0, waiting: 0, done: 0 };

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Gná</h1>
          <p className="stage-deck">
            The one mail desk · read-only · Gná drafts, the Allfather sends
          </p>
        </div>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <select
            className="input"
            aria-label="account"
            value={account}
            onChange={(e) => {
              setAccount(e.target.value);
              void loadQueue(e.target.value, hours);
            }}
          >
            {accounts.map((a) => (
              <option key={a} value={a}>
                {a}
              </option>
            ))}
          </select>
          <select
            className="input"
            aria-label="window"
            value={hours}
            onChange={(e) => {
              const next = Number(e.target.value);
              setHours(next);
              void loadQueue(account, next);
            }}
          >
            <option value={24}>24 h</option>
            <option value={48}>48 h</option>
            <option value={168}>7 d</option>
          </select>
          <button className="btn" onClick={() => void loadQueue(account, hours)} disabled={busy}>
            {busy ? 'reading…' : 'refresh'}
          </button>
        </div>
      </div>

      {error ? (
        <section className="panel" style={{ marginBottom: 'var(--ymir-space-4)' }}>
          <div className="panel-body">
            <p className="mono" style={{ color: 'var(--ymir-danger)', margin: 0 }}>
              {error}
            </p>
            <p className="dim" style={{ margin: '8px 0 0' }}>
              The desk is not an empty inbox: raise it with
              <code className="mono"> python3 hodd/bin/gna-agent/gna_desk.py</code> in the home.
            </p>
          </div>
        </section>
      ) : null}

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Needs you" value={counts.needs_you} tone={counts.needs_you ? 'var(--ymir-danger)' : 'var(--ymir-ok)'} delta="a decision, not a reading" />
        <MetricTile label="Unsure" value={counts.unsure} delta="teach the book" />
        <MetricTile label="Waiting" value={counts.waiting} delta={queue?.oldest_waiting ? `oldest ${queue.oldest_waiting.slice(0, 10)}` : 'nothing out'} />
        <MetricTile label="Done" value={counts.done} tone="var(--ymir-ok)" delta="recorded · nothing sent" />
      </div>

      <div className="grid-2" style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: 'var(--ymir-space-4)' }}>
        {COLUMNS.map((col) => {
          const rows = queue?.columns?.[col.key] ?? [];
          return (
            <section className="panel" key={col.key}>
              <div className="panel-head">
                <div className="panel-title">
                  <span className="glyph" aria-hidden="true">ᚷ</span>
                  {col.label}
                  <span className="muted"> · {rows.length}</span>
                </div>
                <span className="dim mono" style={{ fontSize: 11 }}>{col.note}</span>
              </div>
              <div className="panel-body flush">
                {rows.length === 0 ? (
                  <div className="empty" style={{ padding: 18 }}>
                    <p className="dim" style={{ margin: 0 }}>nothing here</p>
                  </div>
                ) : (
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>From</th>
                        <th>Subject</th>
                        <th>Proposed</th>
                      </tr>
                    </thead>
                    <tbody>
                      {rows.map((row) => (
                        <tr
                          key={row.id}
                          onClick={() => void openMessage(row)}
                          style={{ cursor: 'pointer' }}
                          title={row.evidence}
                        >
                          <td className="mono" style={{ maxWidth: 150, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                            {row.from.name || row.from.email}
                          </td>
                          <td style={{ maxWidth: 260, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                            {row.subject || '(no subject)'}
                          </td>
                          <td className="mono dim">
                            {row.proposed_action}
                            <span className="muted"> · {Math.round((row.confidence ?? 0) * 100)}%</span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>
            </section>
          );
        })}
      </div>

      {open ? (
        <section className="panel" style={{ marginTop: 'var(--ymir-space-4)' }}>
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᚷ</span>
              {open.subject || '(no subject)'}
            </div>
            <button className="btn" onClick={() => setOpen(null)}>
              close
            </button>
          </div>
          <div className="panel-body">
            <p className="mono" style={{ margin: '0 0 8px' }}>
              {open.from.name} &lt;{open.from.email}&gt; · {open.received_at} · {open.account}
            </p>
            <p className="dim" style={{ margin: '0 0 12px' }}>
              <strong>{open.classification}</strong> · {Math.round((open.confidence ?? 0) * 100)}% ·{' '}
              proposed <strong>{open.proposed_action}</strong> · matched by {open.matched_by}
              {open.person_id ? ` · ${open.person_id}` : ''}
              {open.project_id ? ` · ${open.project_id}` : ''}
            </p>
            <p className="mono dim" style={{ margin: '0 0 12px' }}>
              {open.evidence}
            </p>
            <pre className="mono" style={{ whiteSpace: 'pre-wrap', maxHeight: 360, overflow: 'auto', margin: 0 }}>
              {open.body_text || '(no plain-text body)'}
            </pre>
          </div>
        </section>
      ) : null}
    </>
  );
}

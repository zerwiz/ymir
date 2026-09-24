import { useEffect, useMemo, useState } from 'react';
import { skuldCall, skuldInit } from '../skuld';

/**
 * PlansBoard — the roadmap, wearing the SAME anatomy as the tickets board
 * (plan 55 folds the plans-wears-tickets-layout errand in): a table with a
 * status filter and a +new door; pressing a row opens the detail sheet with
 * the plan's body and the tickets it rides. Every plan cut from the tickets —
 * a plan's tickets must exist before the plan does.
 */
function esc(s: string | undefined | null): string {
  const d = document.createElement('div');
  d.textContent = s ?? '';
  return d.innerHTML;
}
function cells(line: string): { id: string; ns: string; st: string; tickets: string; title: string } {
  const c = line.split('|');
  return { id: c[0] ?? '', ns: c[1] ?? '', st: c[2] ?? '', tickets: c[3] ?? '', title: c.slice(4).join('|') };
}

export default function PlansBoard() {
  const [rows, setRows] = useState<string[]>([]);
  const [tickets, setTickets] = useState<string[]>([]);
  const [fStatus, setFStatus] = useState('');
  const [msg, setMsg] = useState<{ cls: string; text: string } | null>(null);
  const [detail, setDetail] = useState<string | null>(null);

  const statuses = useMemo(() => Array.from(new Set(rows.map((r) => cells(r).st))), [rows]);
  const visible = useMemo(
    () => rows.filter((r) => !fStatus || cells(r).st === fStatus),
    [rows, fStatus],
  );

  useEffect(() => {
    void (async () => {
      await skuldInit().catch(() => undefined);
      const t = await skuldCall('tickets/list', { namespace: 'ymir' });
      setTickets((t.split('\n') ?? []).filter(Boolean));
      const p = await skuldCall('plans/list', { namespace: 'ymir' });
      setRows((p.split('\n') ?? []).filter(Boolean));
    })();
  }, []);

  async function loadPlans() {
    const p = await skuldCall('plans/list', { namespace: 'ymir' });
    setRows((p.split('\n') ?? []).filter(Boolean));
  }

  const d = detail ? detail.split('|') : [];

  return (
    <>
      <header className="shead">
        <p className="skicker"><span aria-hidden="true">ᛚ</span> the plans · the roadmap</p>
        <h1>the roadmap</h1>
        <p className="ssub">every plan cut from the tickets — its body, its state, the tickets it rides</p>
      </header>

      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛚ</span>
            the plans <span className="mono dim" style={{ marginLeft: '.4rem', fontSize: '.72rem' }}>{visible.length}</span>
          </div>
          <button type="button" className="td-act" onClick={() => document.getElementById('cut-plan')?.scrollIntoView({ behavior: 'smooth' })}>
            + new plan
          </button>
        </div>
        <div className="panel-body flush">
          <div className="filters">
            <select value={fStatus} onChange={(e) => setFStatus(e.target.value)}>
              <option value="">state: any</option>
              {statuses.map((s) => <option key={s} value={s}>{s}</option>)}
            </select>
          </div>
          <table className="tick-table">
            <thead>
              <tr><th>ID</th><th>title</th><th>state</th><th>rides</th></tr>
            </thead>
            <tbody>
              {visible.length === 0 && (
                <tr><td colSpan={4} className="dim" style={{ padding: '.6rem .7rem' }}>no plans cut yet — the tickets board waits at #/tickets</td></tr>
              )}
              {visible.map((r) => {
                const c = cells(r);
                return (
                  <tr
                    key={c.id}
                    onClick={async () => {
                      const raw = await skuldCall('plans/get', { id: parseInt(c.id, 10) });
                      setDetail(raw);
                    }}
                  >
                    <td className="mono dim">#{esc(c.id)}</td>
                    <td>{esc(c.title)}</td>
                    <td><span className="mono dim">{esc(c.st)}</span></td>
                    <td className="mono dim">{esc(c.tickets || '-')}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section className="panel" id="cut-plan">
        <div className="panel-head">
          <div className="panel-title"><span className="glyph" aria-hidden="true">ᚲ</span>cut a plan</div>
        </div>
        <div className="panel-body">
          <form
            className="book-form"
            onSubmit={async (e) => {
              e.preventDefault();
              const f = new FormData(e.currentTarget);
              const r = await skuldCall('plans/create', {
                namespace: f.get('namespace'),
                title: f.get('title'),
                body: f.get('body'),
                tickets: Array.from(e.currentTarget.querySelectorAll<HTMLOptionElement>('#ticket-pick option:checked')).map((o) => parseInt(o.value, 10)),
              });
              setMsg({ cls: /created/.test(r) ? 'ok' : 'err', text: r });
              if (/created/.test(r)) {
                await loadPlans();
              }
            }}
          >
            <select name="namespace" defaultValue="ymir" style={{ background: 'var(--hall-bg)', color: 'var(--hall-bone)', border: '1px solid var(--hall-steel)', borderRadius: 2, padding: '.5rem .6rem' }}>
              <option>ymir</option>
            </select>
            <input name="title" placeholder="plan title" required />
            <textarea name="body" rows={4} placeholder="the plan's body — anything plan-sized is written first" required />
            <div className="book-row" style={{ alignItems: 'flex-start' }}>
              <select name="tickets" id="ticket-pick" multiple size={6} style={{ minHeight: '7.5rem', background: 'var(--hall-bg)', color: 'var(--hall-bone)', border: '1px solid var(--hall-steel)', borderRadius: 2, padding: '.3rem .4rem', font: 'inherit' }}>
                {tickets.length === 0 && <option disabled>reading the tickets…</option>}
                {tickets.map((t) => {
                  const c = t.split('|');
                  return (
                    <option key={c[0]} value={c[0]}>{c[2]}/{c[1]}  {c[5]}</option>
                  );
                })}
              </select>
              <span className="mono dim" style={{ fontSize: '.68rem' }}>press to pick the tickets the plan rides (multiselect)</span>
              <button type="submit">cut the plan</button>
            </div>
            {msg && <div className={`msg ${msg.cls}`}>{msg.text}</div>}
          </form>
        </div>
      </section>

      <div className="hall-foot" style={{ marginTop: '1rem', padding: '.6rem .9rem', background: 'var(--hall-glass)', border: '1px solid var(--hall-steel)', borderRadius: 8 }}>
        <div className="hall-foot-close" style={{ color: 'var(--hall-bone-dim)', fontSize: '.8rem' }}>
          one book, two doors — the MCP and the hall · the plans ride the tickets — a plan's tickets must exist before the plan does
        </div>
      </div>

      {detail && d.length >= 3 && (
        <div className="ticket-detail" role="dialog" aria-modal="true">
          <div className="td-backdrop" onClick={() => setDetail(null)} />
          <div className="td-panel">
            <div className="td-head" style={{ display: 'flex', alignItems: 'center' }}>
              <span className="mono dim">plan #{esc(d[0])} · {esc(d[1])} · {esc(d[2] ?? '')}</span>
              <button type="button" className="td-close" onClick={() => setDetail(null)}>✕</button>
            </div>
            <h2>{esc(cells(detail).title)}</h2>
            <p className="td-desc">{esc(d[3] ?? '')}</p>
            <div className="td-row">
              <span className="mono dim">rides tickets: {esc(cells(detail).tickets || '-')}</span>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
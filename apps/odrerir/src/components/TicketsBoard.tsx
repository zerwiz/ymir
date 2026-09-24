import { useEffect, useMemo, useState } from 'react';
import { skuldCall, skuldInit } from '../skuld';

/**
 * TicketsBoard — the hall's book (plan 43), carried faithful from the old
 * Astro hall into the Hlidskjalf-type shell (plan 55): the filterable/sortable
 * table with bulk power and a +new door; pressing a row opens the detail sheet
 * with the stat-strip, the state march, the assignee's pick and the comments
 * thread. The SAME anatomy the plans board wears.
 */
const COLORS: Record<string, string> = {
  Backlog: '#6B7280',
  Planned: '#7d5f2a',
  Ready: '#96a0a8',
  'In Progress': '#3B82F6',
  'Submitted for Review': '#EAB308',
  'In Review': '#EAB308',
  Approved: '#22C55E',
  Done: '#22C55E',
  'Changes Requested': '#F97316',
};
const MARCH: Record<string, string[]> = {
  Backlog: ['Planned'],
  Planned: ['Ready'],
  Ready: ['In Progress'],
  'In Progress': ['Submitted for Review', 'Changes Requested'],
  'Submitted for Review': ['In Review'],
  'In Review': ['Approved', 'Changes Requested'],
  Approved: ['Done'],
  Done: [],
  'Changes Requested': ['In Progress'],
};
const STATUSES = [
  'Backlog', 'Planned', 'Ready', 'In Progress', 'Submitted for Review',
  'In Review', 'Approved', 'Done', 'Changes Requested',
];
const LABELS = ['fleet', 'infra', 'ui', 'api', 'release', 'vault', 'review', 'craft'];

function esc(s: string | undefined | null): string {
  const d = document.createElement('div');
  d.textContent = s ?? '';
  return d.innerHTML;
}
function stBadge(st: string): string {
  const c = COLORS[st] ?? '#c9973f';
  return `<span class="st-badge" style="background:${c}22;color:${c};border:1px solid ${c}">${esc(st)}</span>`;
}
function cells(line: string): { id: string; no: string; ns: string; st: string; pr: string; title: string; who: string; par: string } {
  const [rawId, no, ns, st, pr, title, who, par] = line.split('|');
  return { id: (rawId ?? '').replace(/^#/, ''), no: no ?? '', ns: ns ?? '', st: st ?? '', pr: pr ?? '', title: title ?? '', who: who ?? '', par: par ?? '' };
}

export default function TicketsBoard() {
  const [rows, setRows] = useState<string[]>([]);
  const [fStatus, setFStatus] = useState('');
  const [fPriority, setFPriority] = useState('');
  const [fAssignee, setFAssignee] = useState('');
  const [sel, setSel] = useState<Set<string>>(new Set());
  const [newOpen, setNewOpen] = useState(false);
  const [msg, setMsg] = useState<{ cls: string; text: string } | null>(null);
  const [detail, setDetail] = useState<string | null>(null); // raw get line
  const [detailComments, setDetailComments] = useState('');
  const [labelsOn, setLabelsOn] = useState<Set<string>>(new Set());

  const statuses = useMemo(() => Array.from(new Set(rows.map((r) => cells(r).st))), [rows]);
  const assignees = useMemo(() => Array.from(new Set(rows.map((r) => cells(r).who).filter(Boolean))), [rows]);

  const visible = useMemo(
    () =>
      rows.filter((r) => {
        const c = cells(r);
        return (!fStatus || c.st === fStatus) && (!fPriority || c.pr === fPriority) && (!fAssignee || c.who === fAssignee);
      }),
    [rows, fStatus, fPriority, fAssignee],
  );

  async function load() {
    const t = await skuldCall('tickets/list', { namespace: 'ymir' });
    setRows((t.split('\n') ?? []).filter(Boolean));
  }

  useEffect(() => {
    void (async () => {
      await skuldInit().catch(() => undefined);
      await load();
    })();
  }, []);

  function toggleSel(id: string, on: boolean) {
    setSel((prev) => {
      const next = new Set(prev);
      if (on) next.add(id);
      else next.delete(id);
      return next;
    });
  }

  async function openDetail(id: string) {
    const raw = await skuldCall('tickets/get', { id: Number(id) || 0 });
    const comments = await skuldCall('comments/list', { id: Number(id) || 0 });
    setDetail(raw);
    setDetailComments(comments);
  }

  const d = detail ? detail.split('|') : [];
  const allCells = useMemo(() => rows.map(cells), [rows]);
  const strip = useMemo(() => {
    const s = { Backlog: 0, Active: 0, Review: 0, Blocked: 0, Done: 0 };
    for (const x of allCells) {
      if (x.st === 'Backlog' || x.st === 'Planned' || x.st === 'Ready') s.Backlog++;
      else if (x.st === 'In Progress') s.Active++;
      else if (x.st === 'Submitted for Review' || x.st === 'In Review') s.Review++;
      else if (x.st === 'Changes Requested') s.Blocked++;
      else if (x.st === 'Done') s.Done++;
    }
    return s;
  }, [allCells]);

  return (
    <>
      <header className="shead">
        <p className="skicker"><span aria-hidden="true">ᛉ</span> skuld · the debts owed</p>
        <h1>The Hall's Book</h1>
        <p className="ssub">the tickets of the fleet — filter, sort, pick, press — the book answers the hand, never the keyboard</p>
      </header>

      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛏ</span>
            the tickets <span className="mono dim" style={{ marginLeft: '.4rem', fontSize: '.72rem' }}>{visible.length}</span>
          </div>
          <button type="button" className="td-act" onClick={() => setNewOpen((v) => !v)}>+ new ticket</button>
        </div>
        <div className="panel-body flush">
          <div className="filters">
            <select value={fStatus} onChange={(e) => setFStatus(e.target.value)}>
              <option value="">status: any</option>
              {statuses.map((s) => <option key={s} value={s}>{s}</option>)}
            </select>
            <select value={fPriority} onChange={(e) => setFPriority(e.target.value)}>
              <option value="">priority: any</option>
              <option>Low</option><option>Medium</option><option>High</option><option>Critical</option>
            </select>
            <select value={fAssignee} onChange={(e) => setFAssignee(e.target.value)}>
              <option value="">assignee: any</option>
              {assignees.map((a) => <option key={a} value={a}>{a}</option>)}
            </select>
          </div>

          {newOpen && (
            <div style={{ padding: '.7rem .9rem', borderBottom: '1px solid var(--hall-steel)' }}>
              <form
                className="book-form"
                onSubmit={async (e) => {
                  e.preventDefault();
                  const f = new FormData(e.currentTarget);
                  const r = await skuldCall('tickets/create', {
                    namespace: f.get('namespace'),
                    title: f.get('title'),
                    description: f.get('description'),
                    priority: f.get('priority'),
                    status: f.get('status'),
                    labels: Array.from(labelsOn),
                  });
                  setMsg({ cls: /created/.test(r) ? 'ok' : 'err', text: r });
                  if (/created/.test(r)) {
                    setNewOpen(false);
                    await load();
                  }
                }}
              >
                <div className="book-row">
                  <select name="namespace"><option>ymir</option></select>
                  <select name="priority"><option>Low</option><option selected>Medium</option><option>High</option><option>Critical</option></select>
                  <select name="status" defaultValue="Ready">
                    {STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
                  </select>
                </div>
                <input name="title" placeholder="title" required />
                <textarea name="description" rows={3} placeholder="description — the deed in the fleet's words" required />
                <div className="book-row">
                  <span className="mono dim" style={{ fontSize: '.68rem' }}>labels:</span>
                  {LABELS.map((l) => (
                    <button
                      type="button"
                      key={l}
                      className={`chip${labelsOn.has(l) ? ' on' : ''}`}
                      onClick={() =>
                        setLabelsOn((prev) => {
                          const next = new Set(prev);
                          if (next.has(l)) next.delete(l);
                          else next.add(l);
                          return next;
                        })
                      }
                    >
                      {l}
                    </button>
                  ))}
                  <button type="submit">cut the ticket</button>
                </div>
                {msg && <div className={`msg ${msg.cls}`}>{msg.text}</div>}
              </form>
            </div>
          )}

          <table className="tick-table">
            <thead>
              <tr>
                <th style={{ width: '2rem' }}>
                  <input
                    type="checkbox"
                    checked={sel.size > 0 && visible.every((r) => sel.has(cells(r).id))}
                    onChange={(e) => {
                      const next = new Set<string>();
                      if (e.target.checked) visible.forEach((r) => next.add(cells(r).id));
                      setSel(next);
                    }}
                  />
                </th>
                <th>ID</th><th>title</th><th>status</th><th>pri</th><th>who</th><th>⇡</th>
              </tr>
            </thead>
            <tbody>
              {visible.length === 0 && (
                <tr><td colSpan={7} className="dim" style={{ padding: '.6rem .7rem' }}>reading the book…</td></tr>
              )}
              {visible.map((r) => {
                const c = cells(r);
                return (
                  <tr
                    key={c.id}
                    onClick={(e) => {
                      if ((e.target as HTMLElement).closest('input')) return;
                      void openDetail(c.id);
                    }}
                  >
                    <td>
                      <input type="checkbox" checked={sel.has(c.id)} onChange={(e) => toggleSel(c.id, e.target.checked)} />
                    </td>
                    <td className="mono dim">{c.ns}/{c.no}</td>
                    <td>{esc(c.title)}</td>
                    <td dangerouslySetInnerHTML={{ __html: stBadge(c.st) }} />
                    <td>{esc(c.pr)}</td>
                    <td className="dim">{esc(c.who)}</td>
                    <td className="dim">{c.par && c.par !== '0' ? `⇡${esc(c.par)}` : ''}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      {sel.size > 0 && (
        <section className="panel" style={{ padding: '.5rem .9rem' }}>
          <div className="book-row">
            <span className="mono dim" style={{ fontSize: '.7rem' }}>{sel.size} selected</span>
            <select
              id="bulk-status"
              defaultValue=""
              style={{ background: 'var(--hall-bg)', color: 'var(--hall-bone)', border: '1px solid var(--hall-steel)', borderRadius: 2, padding: '.3rem .5rem', fontSize: '.72rem' }}
              onChange={async (e) => {
                const to = e.target.value;
                if (!to) return;
                for (const id of Array.from(sel)) await skuldCall('tickets/update', { id: parseInt(id, 10), status: to });
                setSel(new Set());
                await load();
              }}
            >
              <option value="">change status…</option>
              {STATUSES.map((s) => <option key={s}>{s}</option>)}
            </select>
          </div>
        </section>
      )}

      {detail && d.length >= 4 && (
        <div className="ticket-detail" role="dialog" aria-modal="true">
          <div className="td-backdrop" onClick={() => setDetail(null)} />
          <div className="td-panel">
            <div className="td-head" style={{ display: 'flex', alignItems: 'center' }}>
              <span className="mono dim">{esc(d[1])}/{esc(d[2] ?? '')} · {esc(d[6] ?? '')}</span>
              <button type="button" className="td-close" onClick={() => setDetail(null)}>✕</button>
            </div>
            <div className="td-strip">
              <div><b>{strip.Backlog}</b><span>Backlog</span></div>
              <div><b>{strip.Active}</b><span>Active</span></div>
              <div><b>{strip.Review}</b><span>Review</span></div>
              <div><b>{strip.Blocked}</b><span>Changes</span></div>
              <div><b>{strip.Done}</b><span>Done</span></div>
            </div>
            <h2>{esc(d[3] ?? '')}</h2>
            <p className="td-desc">{esc(d[4] ?? '')}</p>
            <div className="td-row">
              <span className="mono dim">{esc(d[5] ?? '')}</span>
              <span className="mono dim">holder:</span>
              <select
                value=""
                style={{ background: 'var(--hall-bg)', color: 'var(--hall-bone)', border: '1px solid var(--hall-steel)', borderRadius: 2, padding: '.3rem .5rem' }}
                onChange={async (e) => {
                  const id = Number(d[0]);
                  if (e.target.value) await skuldCall('tickets/update', { id, assignee: e.target.value });
                }}
              >
                <option value="">—</option>
                {allCells.filter((x) => x.st !== 'Done').map((x) => (
                  <option key={x.id} value={x.who || 'hall'}>{x.who || 'hall'}</option>
                ))}
              </select>
            </div>
            <div className="td-actions">
              {(MARCH[d[6] ?? ''] ?? []).map((s) => (
                <button
                  type="button"
                  key={s}
                  className="td-act"
                  onClick={async () => {
                    const id = Number(d[0]);
                    const r = await skuldCall('tickets/update', { id, status: s });
                    if (/updated/.test(r)) {
                      setDetail(null);
                      await load();
                    }
                  }}
                >
                  → {s}
                </button>
              ))}
              {!(MARCH[d[6] ?? ''] ?? []).length && <span className="mono dim">terminal — {esc(d[6] ?? '')}</span>}
            </div>
            <div className="td-comments">
              {detailComments.split('\n').filter(Boolean).map((x, i) => {
                const p = x.split('|');
                return (
                  <div className="td-comment" key={i}>
                    <span className="a">{esc(p[1])} · {esc(p[3])}</span>
                    <div>{esc(p[2])}</div>
                  </div>
                );
              })}
              {!detailComments.trim() && <div className="mono dim" style={{ fontSize: '.7rem' }}>no comments yet</div>}
            </div>
            <form
              className="book-form"
              style={{ marginTop: '.7rem' }}
              onSubmit={async (e) => {
                e.preventDefault();
                const v = new FormData(e.currentTarget).get('td-comment-text') as string;
                if (!v?.trim()) return;
                const r = await skuldCall('comments/post', { id: Number(d[0]), body: v.trim() });
                if (/carved/.test(r)) setDetail(null);
              }}
            >
              <div className="book-row">
                <input name="td-comment-text" placeholder="a word on this ticket" />
                <button type="submit" className="td-act">carve</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
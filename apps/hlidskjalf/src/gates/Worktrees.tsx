import { useEffect, useState } from 'react';

type WT = { id: string; branch: string; path: string; head: string; agent: string };

export function Worktrees() {
  const [rows, setRows] = useState<WT[]>([]);
  const [err, setErr] = useState('');

  useEffect(() => {
    let live = true;
    fetch('/api/worktrees')
      .then((r) => r.json())
      .then((d) => { if (live) setRows(Array.isArray(d) ? d : []); })
      .catch((e) => { if (live) setErr(String(e)); });
    return () => { live = false; };
  }, []);

  return (
    <div style={{ padding: 20 }}>
      <h2 style={{ margin: '0 0 12px' }}>Worktrees</h2>
      {err && <p style={{ color: 'crimson' }}>{err}</p>}
      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
        <thead>
          <tr>
            {['id', 'branch', 'agent', 'head', 'path'].map((h) => (
              <th key={h} style={{ textAlign: 'left', borderBottom: '1px solid #333', padding: 6 }}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((w) => (
            <tr key={w.path}>
              <td style={{ padding: 6 }}>{w.id}</td>
              <td style={{ padding: 6 }}>{w.branch}</td>
              <td style={{ padding: 6 }}>{w.agent}</td>
              <td style={{ padding: 6, fontFamily: 'monospace' }}>{w.head}</td>
              <td style={{ padding: 6, fontFamily: 'monospace', fontSize: 12, opacity: 0.8 }}>{w.path}</td>
            </tr>
          ))}
          {rows.length === 0 && (
            <tr><td colSpan={5} style={{ padding: 6, opacity: 0.6 }}>no worktrees</td></tr>
          )}
        </tbody>
      </table>
    </div>
  );
}

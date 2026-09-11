import { useYmir } from '../state/store';
import { useUI } from '../state/ui';
import { StatusChip } from '../components/Status';
import { MetricTile } from '../components/MetricTile';
import type { ProcessInfo } from '../types';

function up(sec: number) {
  if (sec <= 0) return '—';
  const d = Math.floor(sec / 86400);
  const h = Math.floor((sec % 86400) / 3600);
  const m = Math.floor((sec % 3600) / 60);
  if (d) return `${d}d ${h}h`;
  if (h) return `${h}h ${m}m`;
  return `${m}m`;
}

export function Processes() {
  const processes = useYmir((s) => s.processes);
  const updateProcess = useYmir((s) => s.updateProcess);
  const { openModal, toast } = useUI();
  const nominal = processes.filter((p) => p.status === 'nominal').length;

  function restart(p: ProcessInfo) {
    openModal({
      variant: 'confirm',
      tone: 'warn',
      glyph: 'ᛞ',
      title: `Restart ${p.name}?`,
      body: `${p.daemon} · ${p.manager}. Valhalla brings the daemon back and counts the restart.`,
      confirmLabel: 'Restart',
      onSubmit: () => {
        updateProcess(p.id, {
          status: 'nominal',
          restarts: p.restarts + 1,
          uptime: 0,
          cpu: 0.4,
          mem: Math.max(24, p.mem),
        });
        toast({ kind: 'ok', title: `${p.name} restarted`, body: 'Valhalla watch restored.' });
      },
    });
  }

  function logs(p: ProcessInfo) {
    openModal({
      variant: 'info',
      tone: p.status === 'down' ? 'danger' : 'info',
      glyph: 'ᛞ',
      title: `Logs — ${p.name}`,
      content: [
        `[valhalla] supervising ${p.name} via ${p.manager}`,
        `[health] status=${p.status} cpu=${p.cpu}% mem=${p.mem}MB restarts=${p.restarts}`,
        `[trace] uptime=${up(p.uptime)}`,
        p.status === 'down'
          ? '[error] process exited (signal SIGKILL) — bring-back scheduled'
          : '[info] heartbeat nominal',
        '[info] observed into Mimirsbrunn · rune carved',
      ].join('\n'),
    });
  }

  function reloadAll() {
    openModal({
      variant: 'confirm',
      tone: 'warn',
      glyph: 'ᛞ',
      title: 'Reload all daemons?',
      body: 'Valhalla will reload every supervised process. The forge stays hot — no work is lost.',
      confirmLabel: 'Reload all',
      onSubmit: () => {
        processes.forEach((p) =>
          updateProcess(p.id, { status: 'nominal', restarts: p.restarts + 1, uptime: 0 }),
        );
        toast({ kind: 'ok', title: 'Fleet reloaded', body: 'All daemons nominal.' });
      },
    });
  }

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Valhalla</h1>
          <p className="stage-deck">
            Process supervision · PM2 · Docker · systemd · dead processes brought back
          </p>
        </div>
        <button className="btn" onClick={reloadAll}>
          <span aria-hidden="true">ᛞ</span> Reload all
        </button>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Healthy" value={`${nominal}/${processes.length}`} tone="var(--ymir-ok)" delta="watched" />
        <MetricTile label="CPU" value={`${processes.reduce((a, p) => a + p.cpu, 0).toFixed(1)}%`} delta="across fleet" />
        <MetricTile label="Memory" value={`${processes.reduce((a, p) => a + p.mem, 0)} MB`} delta="resident" />
        <MetricTile label="Restarts" value={processes.reduce((a, p) => a + p.restarts, 0)} tone="var(--ymir-warn)" delta="bring-back events" />
      </div>

      <section className="panel">
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛞ</span>
            Daemons
          </div>
        </div>
        <div className="panel-body flush">
          <table className="data-table">
            <thead>
              <tr>
                <th>Process</th>
                <th>Role</th>
                <th>Manager</th>
                <th>Status</th>
                <th>CPU</th>
                <th>Mem</th>
                <th>Restarts</th>
                <th>Uptime</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {processes.map((p) => (
                <tr key={p.id}>
                  <td className="mono" style={{ color: 'var(--ymir-text-0)' }}>
                    {p.name}
                  </td>
                  <td className="muted">{p.daemon}</td>
                  <td className="mono">{p.manager}</td>
                  <td>
                    <StatusChip status={p.status} />
                  </td>
                  <td className="num">{p.cpu.toFixed(1)}%</td>
                  <td className="num">{p.mem} MB</td>
                  <td className="num" style={{ color: p.restarts ? 'var(--ymir-warn)' : undefined }}>
                    {p.restarts}
                  </td>
                  <td className="num">{up(p.uptime)}</td>
                  <td>
                    <div className="row">
                      <button className="btn" style={{ padding: '4px 10px' }} onClick={() => restart(p)}>
                        Restart
                      </button>
                      <button className="btn" style={{ padding: '4px 10px' }} onClick={() => logs(p)}>
                        Logs
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

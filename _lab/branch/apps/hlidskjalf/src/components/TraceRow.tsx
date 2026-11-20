import type { RuneEntry } from '../types';

const LEVEL_COLOR: Record<RuneEntry['level'], string> = {
  info: 'var(--ymir-info)',
  ok: 'var(--ymir-ok)',
  warn: 'var(--ymir-warn)',
  danger: 'var(--ymir-danger)',
};

function fmt(ts: string) {
  const d = new Date(ts);
  return d.toLocaleTimeString('en-GB', { hour12: false }) + '.' + String(d.getMilliseconds()).padStart(3, '0');
}

export function TraceRow({ rune }: { rune: RuneEntry }) {
  return (
    <div className="trace-row" role="row">
      <span className="ts">{fmt(rune.ts)}</span>
      <span className="agent">{rune.agent}</span>
      <span className="module">{rune.module}</span>
      <span className="event" style={{ color: LEVEL_COLOR[rune.level] }} title={rune.event}>
        <span aria-hidden="true">◆ </span>
        {rune.event}
      </span>
      <span className="checksum">{rune.checksum}</span>
    </div>
  );
}

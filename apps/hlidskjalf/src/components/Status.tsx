import type { AgentStatus } from '../types';
import { STATUS_META } from '../data/realms';

export function StatusChip({ status }: { status: AgentStatus }) {
  const meta = STATUS_META[status];
  return (
    <span className={`status status-${meta.tone}`} title={meta.label}>
      <span className="dot" aria-hidden="true">
        {meta.glyph}
      </span>
      {meta.label}
    </span>
  );
}

export function StatusDot({ status }: { status: AgentStatus }) {
  const meta = STATUS_META[status];
  return (
    <span
      className={`status status-${meta.tone}`}
      aria-label={meta.label}
      style={{ padding: '2px 6px' }}
    >
      <span className="dot" aria-hidden="true">
        {meta.glyph}
      </span>
    </span>
  );
}

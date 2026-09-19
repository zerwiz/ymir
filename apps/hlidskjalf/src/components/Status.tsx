import type { AgentStatus } from '../types';
import { STATUS_META } from '../data/realms';

export function StatusChip({ status }: { status: AgentStatus }) {
  // An unknown status must never take a panel down. The fleet reports states the
  // chip was never taught - 'seated' arrived with the roster-first fleet - and
  // STATUS_META[unknown] is undefined, so meta.tone threw and killed the gate.
  const meta =
    STATUS_META[status] ??
    STATUS_META.nominal ??
    Object.values(STATUS_META)[0];
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

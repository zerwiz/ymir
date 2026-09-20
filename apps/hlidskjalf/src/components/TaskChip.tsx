import type { TaskState } from '../types';
import { TASK_STATE_META } from '../data/realms';

const TONE_COLOR: Record<string, string> = {
  info: 'var(--ymir-info)',
  nominal: 'var(--ymir-ok)',
  degraded: 'var(--ymir-warn)',
  down: 'var(--ymir-danger)',
};

export function TaskChip({ state }: { state: TaskState }) {
  const meta = TASK_STATE_META[state];
  return (
    <span
      className="task-chip"
      style={{ color: TONE_COLOR[meta.tone] }}
      title={state}
    >
      <span aria-hidden="true">{meta.glyph}</span>
      {meta.label}
    </span>
  );
}

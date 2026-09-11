import type { CSSProperties } from 'react';
import type { AgentCard as AgentCardType } from '../types';
import { HOUSES } from '../data/realms';
import { StatusChip } from './Status';
import { RuneTag } from './RuneTag';

export function AgentCard({
  agent,
  onSelect,
  selected,
}: {
  agent: AgentCardType;
  onSelect?: (id: string) => void;
  selected?: boolean;
}) {
  const house = HOUSES[agent.house];
  return (
    <article
      className="agent-card"
      style={{ '--house': house.accent } as CSSProperties}
    >
      <div className="ac-head">
        <div className="agent-seal" aria-hidden="true">
          {house.glyph}
        </div>
        <div className="grow">
          <div className="row-between">
            <div className="agent-name">{agent.name}</div>
            <StatusChip status={agent.status} />
          </div>
          <div className="agent-role">{agent.role}</div>
        </div>
      </div>

      <div className="agent-skills">
        <RuneTag label={house.name} color={house.accent} glyph={house.glyph} />
        {agent.skills.slice(0, 3).map((s) => (
          <RuneTag key={s} label={s} />
        ))}
      </div>

      <div className="agent-meta">
        <span className="mono">{agent.interface.protocol}</span>
        <span aria-hidden="true">·</span>
        <span className="mono truncate">{agent.interface.endpoint}</span>
        <span aria-hidden="true">·</span>
        <span className="mono">{agent.interface.signed ? 'JWS ✓' : 'UNSIGNED'}</span>
      </div>

      <div className="agent-stats">
        <span>
          model <b>{agent.model}</b>
        </span>
        <span>
          tasks <b>{agent.tasksDone}</b>
        </span>
        <span>
          trace <b>{agent.traceability.toFixed(3)}</b>
        </span>
      </div>

      {onSelect ? (
        <button
          className="btn"
          onClick={() => onSelect(agent.id)}
          aria-pressed={selected}
          style={{ alignSelf: 'flex-start' }}
        >
          <span aria-hidden="true">ᛉ</span> Inspect card
        </button>
      ) : null}
    </article>
  );
}

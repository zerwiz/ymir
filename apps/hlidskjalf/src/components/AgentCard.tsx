import type { CSSProperties } from 'react';
import type { AgentCard as AgentCardType } from '../types';
import { DOMAINS } from '../data/realms';
import { useYmir } from '../state/store';
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
  const house = DOMAINS[agent.domain] ?? DOMAINS.ymirlabs;
  const demo = useYmir((s) => s.demo);
  const runes = useYmir((s) => s.runes);
  // Live cards show only real, sourced figures; the seeded stats stay in demo.
  const tasks = demo
    ? agent.tasksDone
    : runes.filter((r) => r.agent === agent.name || r.agent === agent.id).length;
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
          tasks <b>{tasks}</b>
        </span>
        {demo ? (
          <span>
            trace <b>{agent.traceability.toFixed(3)}</b>
          </span>
        ) : null}
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

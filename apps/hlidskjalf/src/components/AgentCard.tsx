import type { CSSProperties } from 'react';
import type { AgentCard as AgentCardType } from '../types';
import { DOMAINS } from '../data/realms';
import { useYmir } from '../state/store';
import { StatusChip } from './Status';

/** An Agent Card states what is TRUE of the agent right now (plan 275 item 9).
 *
 * What it must never do again: call an unseated roster figure NOMINAL, print an
 * empty model, or wear an invented organisation's name (Utgard Studios, Runestone
 * Labs, Muninn Labs). Every line below is a field the connector read from a pane,
 * a launch record, or the operator's own config — and a field it could not read
 * says so.
 */
export function AgentCard({
  agent,
  onSelect,
  selected,
}: {
  agent: AgentCardType;
  onSelect?: (id: string) => void;
  selected?: boolean;
}) {
  // The house colour and glyph are decoration from the roster's domain; the domain
  // NAME is invented, so it is never printed.
  const house = DOMAINS[agent.domain] ?? DOMAINS.ymirlabs;
  const runes = useYmir((s) => s.runes);
  const tasks = runes.filter((r) => r.agent === agent.name || r.agent === agent.id).length;
  const model = agent.model || 'unknown';
  const alive = agent.alive ?? agent.status === 'nominal';

  return (
    <article
      className="agent-card"
      data-alive={alive ? 'yes' : 'no'}
      style={{ '--house': house.accent } as CSSProperties}
    >
      <div className="ac-head">
        <div className="agent-seal" aria-hidden="true">
          {house.glyph}
        </div>
        <div className="grow">
          <div className="row-between">
            <div className="agent-name" title={agent.name}>{agent.name}</div>
            <StatusChip status={agent.status} />
          </div>
          <div className="agent-role">{agent.role}</div>
        </div>
      </div>

      <div className="agent-meta">
        <span className="mono" title="the harness actually running it">
          {agent.harness || '—'}
        </span>
        <span aria-hidden="true">·</span>
        <span className="mono truncate" title={model}>
          {model}
        </span>
      </div>

      <div className="agent-meta">
        <span className="mono truncate" title={agent.paneLabel || 'no pane holds it'}>
          {agent.paneLabel || 'not seated'}
        </span>
        <span aria-hidden="true">·</span>
        <span className="mono">{agent.machine || '—'}</span>
      </div>

      <div className="agent-meta">
        <span className="mono truncate" title={agent.errandClaim || agent.errand || 'no errand record'}>
          {agent.errand
            ? `${agent.errand}${agent.errandState ? ` · ${agent.errandState}` : ''}`
            : alive
              ? agent.role || 'alive'
              : 'no errand'}
        </span>
      </div>

      {agent.lastMessage ? (
        <div className="agent-last" title={`${agent.lastMessageFrom || ''} → ${agent.name}: ${agent.lastMessage}`}>
          <span aria-hidden="true">↦ </span>
          {agent.lastMessage}
        </div>
      ) : null}

      <div className="agent-skills">
        <span className="mono dim" style={{ fontSize: 10 }}>
          {agent.interface.protocol} · {agent.interface.endpoint || 'no endpoint'} ·{' '}
          {agent.interface.signed ? 'signed' : 'no JWS'}
        </span>
        <span className="mono dim" style={{ fontSize: 10 }}>
          {tasks} runes
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

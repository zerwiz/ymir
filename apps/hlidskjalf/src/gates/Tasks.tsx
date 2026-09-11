import { useState } from 'react';
import { useYmir } from '../state/store';
import { useUI } from '../state/ui';
import { TASK_STATE_META, TASK_STATES } from '../data/realms';
import { TaskChip } from '../components/TaskChip';
import { RuneTag } from '../components/RuneTag';

export function Tasks() {
  const tasks = useYmir((s) => s.tasks);
  const pushStream = useYmir((s) => s.pushStream);
  const { openModal, toast } = useUI();
  const [selectedId, setSelectedId] = useState<string | null>(tasks[0]?.id ?? null);
  const selected = tasks.find((t) => t.id === selectedId) ?? null;

  function announce() {
    if (!selected) return;
    pushStream({
      id: `ann-${selected.id}-${Date.now()}`,
      ts: new Date().toISOString(),
      kind: 'ratatoskr',
      from: selected.agent,
      to: 'Kaia',
      taskId: selected.id,
      state: selected.state,
      module: 'ratatoskr',
      message: `${selected.id} announced ${selected.state} to peers`,
      checksum: Math.random().toString(16).slice(2, 8),
    });
    toast({ kind: 'info', title: 'State announced', body: `${selected.id} → ${selected.state}` });
  }

  function recall() {
    if (!selected) return;
    openModal({
      variant: 'info',
      tone: 'info',
      glyph: 'ᛜ',
      title: `Recall — ${selected.id}`,
      body: `Well returned ${selected.log.length} episodes for ${selected.agent}. Drink before you act.`,
      content: selected.log.join('\n'),
    });
  }

  const byState = TASK_STATES.map((state) => ({
    state,
    items: tasks.filter((t) => t.state === state),
  }));

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">The Tasks</h1>
          <p className="stage-deck">
            A2A lifecycle · SUBMITTED → WORKING → TERMINAL · terminal states never restart
          </p>
        </div>
      </div>

      <div className="gate-grid" style={{ gridTemplateColumns: 'minmax(0, 1fr) 380px' }}>
        <div className="board">
          {byState.map((col) => {
            const meta = TASK_STATE_META[col.state];
            return (
              <div className="board-col" key={col.state}>
                <div className="board-col-head">
                  <span className="row">
                    <span aria-hidden="true">{meta.glyph}</span>
                    <span className="mono" style={{ fontSize: 12 }}>
                      {meta.label}
                    </span>
                  </span>
                  <span className="gate-count">{col.items.length}</span>
                </div>
                <div className="board-col-body">
                  {col.items.map((t) => (
                    <button
                      key={t.id}
                      className="task-mini"
                      onClick={() => setSelectedId(t.id)}
                      aria-selected={selectedId === t.id}
                    >
                      <div className="tm-title">{t.title}</div>
                      <div className="tm-meta">
                        <span>{t.agent}</span>
                        <span>{t.order}</span>
                      </div>
                      <div style={{ marginTop: 8 }}>
                        <div className="progress">
                          <span style={{ width: `${t.progress}%` }} />
                        </div>
                      </div>
                    </button>
                  ))}
                  {col.items.length === 0 ? (
                    <div className="mono dim" style={{ fontSize: 11, padding: 8 }}>
                      — empty —
                    </div>
                  ) : null}
                </div>
              </div>
            );
          })}
        </div>

        <section className="panel task-detail">
          {selected ? (
            <>
              <div className="panel-head">
                <div className="panel-title">
                  <span className="glyph" aria-hidden="true">ᛏ</span>
                  {selected.id}
                </div>
                <TaskChip state={selected.state} />
              </div>
              <div className="panel-body col" style={{ gap: 'var(--ymir-space-3)' }}>
                <h2 style={{ fontSize: 18, lineHeight: 1.3 }}>{selected.title}</h2>
                <div className="row" style={{ flexWrap: 'wrap', gap: 6 }}>
                  <RuneTag label={selected.order} glyph="ᛟ" color="var(--ymir-cyan-1)" />
                  <RuneTag label={selected.agent} glyph="ᚠ" />
                </div>
                <div className="progress">
                  <span style={{ width: `${selected.progress}%` }} />
                </div>
                <div className="row-between mono dim" style={{ fontSize: 11 }}>
                  <span>started {new Date(selected.startedAt).toLocaleTimeString('en-GB', { hour12: false })}</span>
                  <span>{selected.progress}%</span>
                </div>

                <div className="eyebrow">Live log</div>
                <div>
                  {selected.log.map((line, i) => (
                    <div className="log-line" key={i}>
                      <span className="caret" aria-hidden="true">›</span>
                      <span>{line}</span>
                    </div>
                  ))}
                </div>

                {selected.artifacts.length > 0 ? (
                  <>
                    <div className="eyebrow">Artifacts</div>
                    <div className="col" style={{ gap: 4 }}>
                      {selected.artifacts.map((a) => (
                        <span className="mono" key={a} style={{ fontSize: 12, color: 'var(--ymir-text-1)' }}>
                          ◆ {a}
                        </span>
                      ))}
                    </div>
                  </>
                ) : null}

                <div className="row" style={{ marginTop: 'var(--ymir-space-2)' }}>
                  <button className="btn btn-primary" onClick={announce}>
                    <span aria-hidden="true">⇄</span> Announce state
                  </button>
                  <button className="btn" onClick={recall}>
                    <span aria-hidden="true">ᛜ</span> Recall context
                  </button>
                </div>
              </div>
            </>
          ) : (
            <div className="empty">
              <span className="glyph" aria-hidden="true">ᛏ</span>
              <p>Select a task from the board.</p>
            </div>
          )}
        </section>
      </div>
    </>
  );
}

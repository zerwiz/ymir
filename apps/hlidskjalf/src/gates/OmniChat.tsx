import { useEffect, useMemo, useState } from 'react';
import { useYmir } from '../state/store';
import { ModelPicker } from '../components/ModelPicker';
import { RealmScope } from '../components/RealmScope';

/**
 * OmniChat — Kaia, with the THREAD first (plan 275 item 24).
 *
 * The old layout was three columns (chats · thread · model + lanes + orders), and
 * under 1040px the third column moved BENEATH the thread — so the model panel, the
 * 35-name "Eindri lanes" list and the quick orders sat between the operator and
 * the conversation, and he had to scroll past them to read an answer. At every
 * width now: the thread is first in the DOM, fills the height, and everything
 * secondary lives in ONE drawer that is closed until it is asked for. Nothing was
 * removed — the chats list, the model picker, the lanes and the quick orders are
 * all in the drawer — and the lanes now name the agents that are actually
 * standing, with their errand, instead of terminal titles.
 */
export function OmniChat() {
  const chat = useYmir((s) => s.chat);
  const sendChat = useYmir((s) => s.sendChat);
  const loadChat = useYmir((s) => s.loadChat);
  const chatSessions = useYmir((s) => s.chatSessions);
  const chatSession = useYmir((s) => s.chatSession);
  const newChat = useYmir((s) => s.newChat);
  const switchChat = useYmir((s) => s.switchChat);
  const deleteChat = useYmir((s) => s.deleteChat);
  const chatModels = useYmir((s) => s.chatModels);
  const chatModel = useYmir((s) => s.chatModel);
  const setChatModel = useYmir((s) => s.setChatModel);
  const chatAgents = useYmir((s) => s.chatAgents);
  const toggleChatAgent = useYmir((s) => s.toggleChatAgent);
  const agents = useYmir((s) => s.agents);
  const [draft, setDraft] = useState('');
  const [drawer, setDrawer] = useState(false);

  useEffect(() => {
    void loadChat();
  }, [loadChat]);

  // Lanes: only the agents that are STANDING, by name and by the errand their own
  // pane names. A roster name nobody is running is not a lane you can focus.
  const lanes = useMemo(
    () => agents.filter((a) => a.live).map((a) => ({ name: a.name, task: a.live?.task ?? '', state: a.live?.state ?? '' })),
    [agents],
  );

  function send() {
    const body = draft.trim();
    if (!body) return;
    sendChat(body);
    setDraft('');
  }

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">OmniChat</h1>
          <p className="stage-deck">Speak with Kaia · she drinks from the well before every dispatch</p>
        </div>
        <button
          type="button"
          className="btn btn-sm"
          aria-expanded={drawer}
          aria-controls="chat-drawer"
          onClick={() => setDrawer((v) => !v)}
          title="Chats · model · Eindri lanes · quick orders"
        >
          <span aria-hidden="true">{drawer ? '▾' : '▸'}</span> Drawer
        </button>
      </div>

      <div className="chat-layout">
        <section className="panel chat-thread">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᚴ</span>
              Kaia — oracle by the well
            </div>
            <span className="status status-ok">
              <span className="dot" aria-hidden="true">ᛟ</span>NOMINAL
            </span>
          </div>

          <div className="chat-scroll">
            {chat.length === 0 ? (
              <div className="empty">
                <span className="glyph" aria-hidden="true">ᚴ</span>
                <p>Ask Kaia anything. She recalls the well before she answers.</p>
              </div>
            ) : null}
            {chat.map((m) => (
              <div key={m.id} className={`bubble ${m.from}${m.error ? ' err' : ''}`}>
                {m.thinking ? (
                  <div className="thinking">
                    <span className="dots" aria-hidden="true"><i /><i /><i /></span>
                    {m.recalling ? 'drawing from the well…' : 'Kaia is thinking…'}
                  </div>
                ) : (
                  <>
                    <div>{m.body}</div>
                    <div className="b-meta">
                      <span>{new Date(m.ts).toLocaleTimeString('en-GB', { hour12: false })}</span>
                      {m.model ? <span className="mono">{m.model}</span> : null}
                      {m.recalling ? <span style={{ color: 'var(--ymir-cyan-1)' }}>◈ recalled the well</span> : null}
                      {m.agents?.length ? <span className="dim">lanes: {m.agents.join(', ')}</span> : null}
                    </div>
                  </>
                )}
              </div>
            ))}
          </div>

          <form
            className="chat-compose"
            onSubmit={(e) => {
              e.preventDefault();
              send();
            }}
          >
            <input
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              placeholder="Ask Kaia…"
              aria-label="Message Kaia"
            />
            <button className="btn btn-primary" type="submit" disabled={!draft.trim()}>
              <span aria-hidden="true">ᚴ</span> Send
            </button>
          </form>
        </section>

        {/* One drawer. Closed by default, so the thread has the whole window. */}
        <div id="chat-drawer" className="chat-drawer" hidden={!drawer}>
          <section className="panel">
            <div className="panel-head">
              <div className="panel-title">
                <span className="glyph" aria-hidden="true">ᛊ</span> Chats
              </div>
              <button className="btn btn-primary btn-sm" onClick={newChat} title="New chat">
                + New
              </button>
            </div>
            <div className="panel-body flush chat-side-list">
              {chatSessions.length === 0 ? (
                <div className="muted" style={{ padding: 12 }}>No chats yet.</div>
              ) : (
                chatSessions.map((s) => (
                  <div
                    key={s.id}
                    className={`chat-session ${s.id === chatSession ? 'active' : ''}`}
                    onClick={() => switchChat(s.id)}
                    role="button"
                    tabIndex={0}
                  >
                    <span className="mono">{s.id}</span>
                    <span className="dim">{s.messages}</span>
                    <button
                      className="icon-btn"
                      aria-label={`Delete ${s.id}`}
                      onClick={(e) => {
                        e.stopPropagation();
                        deleteChat(s.id);
                      }}
                    >
                      ✕
                    </button>
                  </div>
                ))
              )}
            </div>
          </section>

          <section className="panel">
            <div className="panel-head">
              <div className="panel-title">
                <span className="glyph" aria-hidden="true">ᛜ</span> Model
              </div>
            </div>
            <div className="panel-body col" style={{ gap: 10 }}>
              <label className="field">
                <span>Connected models · free-type any id</span>
                <ModelPicker
                  value={chatModel}
                  onChange={setChatModel}
                  models={chatModels}
                  placeholder="default (auto-detect)"
                />
              </label>
              <RealmScope hint="The realm Kaia dispatches into" />
              <div className="row-between">
                <span className="muted">well</span>
                <span className="mono" style={{ color: 'var(--ymir-ok)' }}>warm</span>
              </div>
            </div>
          </section>

          <section className="panel">
            <div className="panel-head">
              <div className="panel-title">
                <span className="glyph" aria-hidden="true">ᛏ</span> Eindri lanes
              </div>
              <span className="mono dim" style={{ fontSize: 10 }}>
                {lanes.length} standing
              </span>
            </div>
            <div className="panel-body col" style={{ gap: 6 }}>
              <div className="dim" style={{ fontSize: 12 }}>
                Focus Kaia on specific agents before she dispatches.
              </div>
              {lanes.length === 0 ? (
                <div className="muted" style={{ fontSize: 12 }}>
                  No agent is standing — nothing to focus. Errands are seated in herdr panes.
                </div>
              ) : (
                <div className="lane-toggles">
                  {lanes.map((a) => (
                    <button
                      key={a.name}
                      className={`chip ${chatAgents.includes(a.name) ? 'on' : ''}`}
                      onClick={() => toggleChatAgent(a.name)}
                      title={`${a.name} — ${a.task || a.state || 'standing'}`}
                    >
                      <span aria-hidden="true">ᛏ</span> {a.name}
                      {a.task ? <span className="lane-task">{a.task}</span> : null}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </section>

          <section className="panel">
            <div className="panel-head">
              <div className="panel-title">
                <span className="glyph" aria-hidden="true">ᛟ</span> Quick orders
              </div>
            </div>
            <div className="panel-body col" style={{ gap: 6 }}>
              {[
                'Recall the well for this project',
                'Dispatch Eindri-01 on the shell',
                'Summarise the runes today',
                'Spawn a Hermes worker (Utgard)',
              ].map((p) => (
                <button key={p} className="btn" style={{ justifyContent: 'flex-start' }} onClick={() => setDraft(p)}>
                  <span aria-hidden="true">ᛟ</span> {p}
                </button>
              ))}
            </div>
          </section>
        </div>
      </div>
    </>
  );
}

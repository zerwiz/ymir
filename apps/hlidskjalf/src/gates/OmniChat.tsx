import { useState } from 'react';
import { useYmir } from '../state/store';

export function OmniChat() {
  const chat = useYmir((s) => s.chat);
  const sendChat = useYmir((s) => s.sendChat);
  const realm = useYmir((s) => s.realm);
  const demo = useYmir((s) => s.demo);
  const [draft, setDraft] = useState('');

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
          <p className="stage-deck">
            Speak with Kaia · she drinks from the well before every dispatch
          </p>
        </div>
      </div>

      <div className="chat-layout">
        <section className="panel" style={{ minHeight: 460 }}>
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
            {chat.map((m) => (
              <div key={m.id} className={`bubble ${m.from}`}>
                <div>{m.body}</div>
                <div className="b-meta">
                  <span>{new Date(m.ts).toLocaleTimeString('en-GB', { hour12: false })}</span>
                  {m.recalling ? <span style={{ color: 'var(--ymir-cyan-1)' }}>◈ recalled the well</span> : null}
                </div>
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
              placeholder={`Command the ${realm} realm…`}
              aria-label="Message Kaia"
            />
            <button className="btn btn-primary" type="submit">
              <span aria-hidden="true">ᚴ</span> Send
            </button>
          </form>
        </section>

        <aside className="col" style={{ gap: 'var(--ymir-space-4)' }}>
          <section className="panel">
            <div className="panel-head">
              <div className="panel-title">
                <span className="glyph" aria-hidden="true">ᛜ</span>
                Context
              </div>
            </div>
            <div className="panel-body col" style={{ gap: 8, fontSize: 13, color: 'var(--ymir-text-1)' }}>
              <div className="row-between">
                <span className="muted">realm</span>
                <span className="mono">{realm}</span>
              </div>
              <div className="row-between">
                <span className="muted">model</span>
                <span className="mono">{demo ? 'demo · seeded' : 'kaia · deepseek-v4-flash'}</span>
              </div>
              <div className="row-between">
                <span className="muted">well</span>
                <span className="mono" style={{ color: 'var(--ymir-ok)' }}>warm</span>
              </div>
              <div className="row-between">
                <span className="muted">veil</span>
                <span className="mono" style={{ color: 'var(--ymir-ok)' }}>armed</span>
              </div>
            </div>
          </section>

          <section className="panel">
            <div className="panel-head">
              <div className="panel-title">
                <span className="glyph" aria-hidden="true">ᛏ</span>
                Quick orders
              </div>
            </div>
            <div className="panel-body col" style={{ gap: 6 }}>
              {[
                'Recall the well for this project',
                'Dispatch Eindri-01 on the shell',
                'Summarise the runes today',
                'Spawn a Hermes worker (Utgard)',
              ].map((p) => (
                <button
                  key={p}
                  className="btn"
                  style={{ justifyContent: 'flex-start' }}
                  onClick={() => setDraft(p)}
                >
                  <span aria-hidden="true">ᛟ</span> {p}
                </button>
              ))}
            </div>
          </section>
        </aside>
      </div>
    </>
  );
}

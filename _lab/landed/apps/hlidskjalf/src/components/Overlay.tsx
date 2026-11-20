import { useEffect, useState } from 'react';
import { useUI, type ModalSpec, type Tone } from '../state/ui';
import { Markdown } from './Markdown';

const TONE_GLYPH: Record<Tone, string> = {
  ok: 'ᛟ',
  info: 'ᛜ',
  warn: 'ᛇ',
  danger: 'ᛪ',
};

function ModalCard({ modal }: { modal: ModalSpec }) {
  const close = useUI((s) => s.closeModal);
  const tone = modal.tone ?? 'info';
  const [values, setValues] = useState<Record<string, string>>(() => {
    const v: Record<string, string> = {};
    for (const f of modal.fields ?? []) v[f.name] = f.defaultValue ?? '';
    return v;
  });

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') close();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [close]);

  function submit() {
    modal.onSubmit?.(values);
    close();
  }

  return (
    <div className="overlay" onMouseDown={close} role="presentation">
      <div
        className="modal"
        role="dialog"
        aria-modal="true"
        aria-label={modal.title}
        onMouseDown={(e) => e.stopPropagation()}
      >
        <div className="modal-head">
          <span className={`status status-${tone === 'ok' ? 'ok' : tone === 'danger' ? 'danger' : tone === 'warn' ? 'warn' : 'info'}`}>
            <span className="dot" aria-hidden="true">{modal.glyph ?? TONE_GLYPH[tone]}</span>
          </span>
          <h2 className="modal-title">{modal.title}</h2>
          <button className="icon-btn" onClick={close} aria-label="Close" style={{ marginLeft: 'auto' }}>
            ✕
          </button>
        </div>

        {modal.body ? <p className="modal-body">{modal.body}</p> : null}

        {modal.content ? (
          modal.format === 'markdown' ? (
            <div className="modal-content md-preview">
              <Markdown source={modal.content} />
            </div>
          ) : (
            <pre className="modal-content mono">{modal.content}</pre>
          )
        ) : null}

        {modal.fields?.length ? (
          <div className="modal-fields">
            {modal.fields.map((f) => (
              <label key={f.name} className="field">
                <span className="eyebrow">{f.label}</span>
                {f.type === 'textarea' ? (
                  <textarea
                    rows={4}
                    value={values[f.name] ?? ''}
                    placeholder={f.placeholder}
                    onChange={(e) => setValues((v) => ({ ...v, [f.name]: e.target.value }))}
                  />
                ) : (
                  <input
                    type={f.type ?? 'text'}
                    value={values[f.name] ?? ''}
                    placeholder={f.placeholder}
                    onChange={(e) => setValues((v) => ({ ...v, [f.name]: e.target.value }))}
                  />
                )}
              </label>
            ))}
          </div>
        ) : null}

        <div className="modal-foot">
          <button className="btn" onClick={close}>
            {modal.variant === 'info' ? 'Close' : modal.cancelLabel ?? 'Cancel'}
          </button>
          {modal.variant !== 'info' ? (
            <button
              className={`btn ${tone === 'danger' ? 'btn-danger' : tone === 'ok' ? 'btn-seal' : 'btn-primary'}`}
              onClick={submit}
            >
              <span aria-hidden="true">{tone === 'ok' ? 'ᛉ' : TONE_GLYPH[tone]}</span>
              {modal.confirmLabel ?? 'Confirm'}
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}

export function Overlay() {
  const modal = useUI((s) => s.modal);
  const toasts = useUI((s) => s.toasts);
  const dismiss = useUI((s) => s.dismiss);

  return (
    <>
      {modal ? <ModalCard modal={modal} /> : null}

      <div className="toast-host" aria-live="polite" aria-atomic="false">
        {toasts.map((t) => (
          <div key={t.id} className={`toast status-${t.kind === 'ok' ? 'ok' : t.kind === 'danger' ? 'danger' : t.kind === 'warn' ? 'warn' : 'info'}`}>
            <span className="toast-glyph" aria-hidden="true">{TONE_GLYPH[t.kind]}</span>
            <div className="col grow">
              <strong>{t.title}</strong>
              {t.body ? <span className="toast-body">{t.body}</span> : null}
            </div>
            <button className="toast-x" onClick={() => dismiss(t.id)} aria-label="Dismiss">
              ✕
            </button>
          </div>
        ))}
      </div>
    </>
  );
}

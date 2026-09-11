import { useEffect, useRef, useState } from 'react';
import { ACCENTS } from '../data/realms';
import { useYmir } from '../state/store';

export function AccentPicker() {
  const accentId = useYmir((s) => s.accentId);
  const custom = useYmir((s) => s.customAccent);
  const setAccent = useYmir((s) => s.setAccent);
  const setCustomAccent = useYmir((s) => s.setCustomAccent);
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onDoc);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDoc);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const currentTint =
    accentId === 'custom'
      ? custom ?? '#38bdf8'
      : accentId === 'realm'
        ? 'var(--realm-tint)'
        : ACCENTS.find((a) => a.id === accentId)?.tint ?? 'var(--ymir-cyan-1)';

  return (
    <div className="menu-wrap" ref={ref}>
      <button
        className="icon-btn"
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-pressed={open}
        onClick={() => setOpen((v) => !v)}
        title="Accent colour"
      >
        <span className="accent-dot" style={{ background: currentTint }} aria-hidden="true" />
      </button>

      {open ? (
        <div className="popover" role="dialog" aria-label="Accent colour">
          <div className="popover-head">
            <span>Accent colour</span>
            <span className="mono dim" style={{ fontSize: 10 }}>
              {accentId === 'realm' ? 'realm default' : accentId}
            </span>
          </div>

          <div className="swatch-grid">
            {ACCENTS.map((a) => (
              <button
                key={a.id}
                className="swatch"
                aria-pressed={accentId === a.id}
                onClick={() => setAccent(a.id)}
                title={a.name}
                style={
                  a.tint
                    ? { background: a.tint }
                    : { background: 'linear-gradient(135deg,#38bdf8,#8b5cf6,#f59e0b)' }
                }
              >
                {a.id === 'realm' ? (
                  <span className="swatch-realm" aria-hidden="true">
                    ᛉ
                  </span>
                ) : null}
                {accentId === a.id ? (
                  <span className="swatch-check" aria-hidden="true">
                    ✓
                  </span>
                ) : null}
              </button>
            ))}
          </div>

          <label className="custom-color">
            <span className="eyebrow">Custom</span>
            <input
              type="color"
              value={custom ?? '#38bdf8'}
              onChange={(e) => setCustomAccent(e.target.value)}
              aria-label="Custom accent colour"
            />
            <span className="mono dim" style={{ marginLeft: 'auto' }}>
              {accentId === 'custom' ? custom : 'pick a hex'}
            </span>
          </label>
        </div>
      ) : null}
    </div>
  );
}

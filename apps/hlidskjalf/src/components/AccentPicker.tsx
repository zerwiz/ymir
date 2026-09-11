import { useEffect, useRef, useState } from 'react';
import { ACCENTS } from '../data/realms';
import { useYmir } from '../state/store';

/** Background presets. `hex: null` is the canonical forge canvas. */
const BACKGROUNDS: { id: string; name: string; hex: string | null }[] = [
  { id: 'forge', name: 'Forge (default)', hex: null },
  { id: 'midnight', name: 'Midnight', hex: '#0a0f1c' },
  { id: 'charcoal', name: 'Charcoal', hex: '#15171b' },
  { id: 'ink', name: 'Ink', hex: '#050608' },
  { id: 'forest', name: 'Forest', hex: '#0a1410' },
  { id: 'plum', name: 'Plum', hex: '#150b1c' },
  { id: 'ocean', name: 'Ocean', hex: '#07131c' },
];

const BG_KEYS = ['--ymir-bg-0', '--ymir-bg-1', '--ymir-bg-2', '--ymir-bg-3'];

/** Repaint the whole hall by re-deriving the canvas tokens from one base hue. */
function applyBackground(hex: string | null): void {
  const root = document.documentElement;
  if (!hex) {
    BG_KEYS.forEach((k) => root.style.removeProperty(k));
    return;
  }
  const lighten = (pct: number) => `color-mix(in srgb, ${hex} ${pct}%, white)`;
  root.style.setProperty('--ymir-bg-0', hex);
  root.style.setProperty('--ymir-bg-1', lighten(90));
  root.style.setProperty('--ymir-bg-2', lighten(82));
  root.style.setProperty('--ymir-bg-3', lighten(72));
}

function loadBg(): string {
  try {
    return localStorage.getItem('ymir.bg') ?? '';
  } catch {
    return '';
  }
}

export function AccentPicker() {
  const accentId = useYmir((s) => s.accentId);
  const custom = useYmir((s) => s.customAccent);
  const setAccent = useYmir((s) => s.setAccent);
  const setCustomAccent = useYmir((s) => s.setCustomAccent);
  const [open, setOpen] = useState(false);
  const [bg, setBg] = useState<string>(loadBg);
  const ref = useRef<HTMLDivElement>(null);

  // Apply the saved background once, and on every change.
  useEffect(() => {
    applyBackground(bg || null);
    try {
      if (bg) localStorage.setItem('ymir.bg', bg);
      else localStorage.removeItem('ymir.bg');
    } catch {
      /* ignore */
    }
  }, [bg]);

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

  /** Back to the hall as it was carved: realm accent, forge canvas. */
  function restore() {
    setAccent('realm');
    setBg('');
  }

  return (
    <div className="menu-wrap" ref={ref}>
      <button
        className="icon-btn"
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-pressed={open}
        onClick={() => setOpen((v) => !v)}
        title="Theme — accent & background"
      >
        <span className="accent-dot" style={{ background: currentTint }} aria-hidden="true" />
      </button>

      {open ? (
        <div className="popover" role="dialog" aria-label="Theme">
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

          <div className="popover-head" style={{ paddingTop: 0 }}>
            <span>Background</span>
            <span className="mono dim" style={{ fontSize: 10 }}>
              {BACKGROUNDS.find((b) => b.hex && b.hex === bg)?.name ?? (bg ? bg : 'default')}
            </span>
          </div>

          <div className="swatch-grid">
            {BACKGROUNDS.map((b) => (
              <button
                key={b.id}
                className="swatch"
                aria-pressed={(b.hex ?? '') === bg}
                onClick={() => setBg(b.hex ?? '')}
                title={b.name}
                style={
                  b.hex
                    ? { background: b.hex, borderColor: 'var(--ymir-steel-2)' }
                    : { background: 'linear-gradient(135deg,#080c14,#101726,#182334)' }
                }
              >
                {b.hex === null ? (
                  <span className="swatch-realm" aria-hidden="true">
                    ᛉ
                  </span>
                ) : null}
                {(b.hex ?? '') === bg ? (
                  <span className="swatch-check" aria-hidden="true">
                    ✓
                  </span>
                ) : null}
              </button>
            ))}
          </div>

          <label className="custom-color">
            <span className="eyebrow">Custom bg</span>
            <input
              type="color"
              value={bg || '#101726'}
              onChange={(e) => setBg(e.target.value)}
              aria-label="Custom background colour"
            />
            <span className="mono dim" style={{ marginLeft: 'auto' }}>
              {bg && !BACKGROUNDS.some((b) => b.hex === bg) ? bg : 'pick a hex'}
            </span>
          </label>

          <button className="btn restore-btn" type="button" onClick={restore}>
            <span aria-hidden="true">ᛉ</span> Restore defaults
          </button>
        </div>
      ) : null}
    </div>
  );
}

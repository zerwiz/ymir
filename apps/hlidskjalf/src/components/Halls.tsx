import { useState } from 'react';
import { gateApi } from '../services/api';

/**
 * The three halls of Ymir — one seat, three rooms. Every surface can raise the
 * others through the gate (`/api/desktop`), so the buttons are the same control
 * however you reach them.
 */
export interface Hall {
  id: 'hlidskjalf' | 'smidja' | 'sessrumnir' | 'odrerir';
  glyph: string;
  name: string;
  blurb: string;
}

export const HALLS: Hall[] = [
  {
    id: 'hlidskjalf',
    glyph: 'ᚺ',
    name: 'Hlidskjalf',
    blurb:
      'The control plane — the high seat. See the whole machine at once: the fleet of agents, tasks, the memory well, the rune ledger, reviews, cron. Start here to know what Ymir is doing.',
  },
  {
    id: 'smidja',
    glyph: 'ᛊ',
    name: 'Smíðja',
    blurb:
      'The smithy — the trace of work in the fire. Watch agent runs phase by phase: envelopes, gates and their evidence, decisions, stats. One eye on the work being made.',
  },
  {
    id: 'sessrumnir',
    glyph: 'ᛋ',
    name: 'Sessrúmnir',
    blurb:
      'The seat-hall — where you converse with Brokk. The chat, your sessions, your code, the file trees for the Hoard, the realms, and your workspaces, and the review rail.',
  },
];

/** Raise a hall's WINDOW — the door the Omarchy bindings use. Exported so the
 *  Topbar's Óðrerir rune raises the app rather than opening a browser tab. */
export async function raise(id: Hall['id']): Promise<void> {
  try {
    await gateApi.desktop(id);
  } catch {
    /* launcher unreachable — stay put, change nothing */
  }
}

const cardStyle: React.CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  gap: '0.5rem',
  textAlign: 'left',
  padding: '1.1rem 1.2rem',
  borderRadius: '12px',
  border: '1px solid var(--ymir-steel-2)',
  background: 'var(--ymir-bg-1)',
  color: 'inherit',
  cursor: 'pointer',
  minWidth: '240px',
  flex: '1 1 240px',
};

/** Post-login chooser: what the three apps are, and where to go. */
export function HallsChooser({ onClose }: { onClose: () => void }): React.JSX.Element {
  const [busy, setBusy] = useState<Hall['id'] | null>(null);
  const enter = async (id: Hall['id']): Promise<void> => {
    if (id !== 'hlidskjalf') {
      setBusy(id);
      await raise(id);
      setBusy(null);
    }
    onClose();
  };
  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Choose your seat"
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 60,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'rgba(14, 12, 9, 0.72)',
        backdropFilter: 'blur(4px)',
        padding: '1.5rem',
      }}
    >
      <div style={{ maxWidth: '900px', width: '100%' }}>
        <h1 style={{ fontSize: '1.5rem', margin: '0 0 0.25rem' }}>Take your seat</h1>
        <p style={{ margin: '0 0 1.25rem', opacity: 0.75 }}>
          Ymir has three halls. They share one login — pick where you want to begin.
        </p>
        <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
          {HALLS.map((h) => (
            <button
              key={h.id}
              type="button"
              style={cardStyle}
              disabled={busy !== null}
              onClick={() => void enter(h.id)}
            >
              <span style={{ fontSize: '1.6rem' }} aria-hidden="true">
                {h.glyph}
              </span>
              <span style={{ fontWeight: 600 }}>{h.name}</span>
              <span style={{ fontSize: '0.85rem', opacity: 0.75, lineHeight: 1.45 }}>{h.blurb}</span>
              <span style={{ marginTop: '0.4rem', fontSize: '0.8rem', opacity: 0.9 }}>
                {busy === h.id ? 'raising…' : h.id === 'hlidskjalf' ? 'You are here — enter →' : 'Open →'}
              </span>
            </button>
          ))}
        </div>
        <button
          type="button"
          onClick={onClose}
          style={{
            marginTop: '1rem',
            background: 'transparent',
            border: 'none',
            color: 'inherit',
            opacity: 0.6,
            cursor: 'pointer',
            fontSize: '0.85rem',
          }}
        >
          Stay in Hlidskjalf
        </button>
      </div>
    </div>
  );
}

/** Compact switcher for the topbar: jump between the three halls. */
export function HallsSwitcher({ current }: { current?: Hall['id'] }): React.JSX.Element {
  return (
    <div role="group" aria-label="Switch hall" style={{ display: 'flex', gap: '2px' }}>
      {HALLS.map((h) => (
        <button
          key={h.id}
          type="button"
          className={`icon-btn ${h.id === current ? 'on' : ''}`}
          title={`${h.name} — ${h.blurb.split('.')[0]}.`}
          aria-label={`Open ${h.name}`}
          aria-current={h.id === current ? 'page' : undefined}
          onClick={() => void raise(h.id)}
        >
          {h.glyph}
        </button>
      ))}
    </div>
  );
}

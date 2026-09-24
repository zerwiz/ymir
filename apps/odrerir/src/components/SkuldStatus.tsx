import { useEffect, useState } from 'react';
import { onSkuldStatus, SKULD_URL, skuldReconnect, type SkuldStatus } from '../skuld';

/**
 * SkuldStatus — the book's connection chip (2026-09-24): the user must know
 * whether the tickets/plans door (Skuld, over the tailnet) is CONNECTED, still
 * ringing, or down — and why. A retry rings again and asks the boards to
 * reload (they listen for 'skuld:retry').
 */
export default function SkuldStatusChip() {
  const [s, setS] = useState<SkuldStatus>({ state: 'idle', detail: '', at: 0 });

  useEffect(() => onSkuldStatus(setS), []);

  const label =
    s.state === 'connected'
      ? 'book connected'
      : s.state === 'connecting'
        ? 'ringing the book…'
        : s.state === 'error'
          ? `book NOT connected — ${s.detail}`
          : 'book idle';

  const tone =
    s.state === 'connected' ? '#22C55E' : s.state === 'connecting' ? '#EAB308' : s.state === 'error' ? '#c2584a' : '#9a8f75';

  return (
    <span className="skuld-chip" title={`${SKULD_URL} — ${s.detail}`}>
      <span className="skuld-dot" style={{ background: tone }} aria-hidden="true" />
      <span className="mono" style={{ fontSize: '.66rem', color: tone }}>{label}</span>
      {s.state === 'error' && (
        <button
          type="button"
          className="td-act"
          style={{ padding: '.15rem .5rem', fontSize: '.62rem' }}
          onClick={() => {
            void skuldReconnect()
              .then(() => window.dispatchEvent(new Event('skuld:retry')))
              .catch(() => undefined);
          }}
        >
          retry
        </button>
      )}
    </span>
  );
}
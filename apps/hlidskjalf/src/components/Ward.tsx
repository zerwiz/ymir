import { useCallback, useEffect, useRef, useState } from 'react';
import { gateApi } from '../services/api';

/**
 * HIMINBJÖRG — the watchtower in the high seat.
 *
 * Garmr notices, Vörðr judges, Gná speaks. This panel is a *glass*, not a door:
 * it reads `/api/ward` (the judged findings, the heartbeat, the pause marker) and
 * says what it sees. It never starts, stops or closes anything — those are
 * `bin/ward/garmr.sh` commands and the operator's hand.
 *
 * The one thing it says loudly: a silent hound. A guardian that has stopped is
 * worse than none, because the quiet reads as safety.
 */
type WardState = {
  paused: boolean;
  heartbeat: string;
  heartbeatAgeSeconds: number;
  silent: boolean;
  findings: number;
  judged: number;
  bySeverity: Record<string, number>;
  newest: Array<{ ts: string; severity: string; line: string; title: string; comm: string; pid: string; reasoning?: { rung: string; model: string } | null }>;
  door: string;
};

const POLL_MS = 30_000;

export function Ward() {
  const [state, setState] = useState<WardState | null>(null);
  const [open, setOpen] = useState(false);
  const panelRef = useRef<HTMLDivElement | null>(null);

  const read = useCallback(async () => {
    try {
      setState(await gateApi.ward());
    } catch {
      setState(null); // the gate is unreachable: say nothing rather than invent a calm
    }
  }, []);

  useEffect(() => {
    void read();
    const beat = window.setInterval(() => void read(), POLL_MS);
    return () => window.clearInterval(beat);
  }, [read]);

  useEffect(() => {
    if (!open) return;
    const away = (e: MouseEvent) => {
      if (!panelRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', away);
    return () => document.removeEventListener('mousedown', away);
  }, [open]);

  const critical = state?.bySeverity?.CRITICAL ?? 0;
  const high = state?.bySeverity?.HIGH ?? 0;
  const tone = state?.paused ? 'warn' : state?.silent ? 'danger' : critical ? 'danger' : high ? 'warn' : 'ok';
  const label = state?.paused ? 'paused' : state?.silent ? 'silent' : `${critical}/${high}`;

  return (
    <div ref={panelRef} style={{ position: 'relative' }}>
      <button
        type="button"
        onClick={() => { setOpen((v) => !v); void read(); }}
        title={`Garmr — the hound (${state?.door ?? 'bin/ward/garmr.sh'})`}
        style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '4px 10px', borderRadius: 999, cursor: 'pointer',
          border: '1px solid var(--ymir-line, #333)', background: 'transparent',
          color: 'inherit', fontSize: 12, letterSpacing: '0.04em',
        }}
      >
        <span aria-hidden>ᛉ</span>
        <span>{state?.paused ? 'hound paused' : 'hound'}</span>
        <span style={{
          width: 7, height: 7, borderRadius: '50%',
          background: tone === 'danger' ? '#e5484d' : tone === 'warn' ? '#e2a336' : '#30a46c',
        }} />
        <span style={{ opacity: 0.7 }}>{label}</span>
      </button>

      {open && (
        <div style={{
          position: 'absolute', right: 0, top: 'calc(100% + 8px)', width: 460, zIndex: 40,
          background: 'var(--ymir-panel, #111)', border: '1px solid var(--ymir-line, #333)',
          borderRadius: 10, padding: 14, fontSize: 12, lineHeight: 1.5,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
            <strong>Himinbjörg — the watchtower</strong>
            <span style={{ opacity: 0.6 }}>{state?.door ?? 'garmr.sh'}</span>
          </div>

          {!state && <p style={{ margin: 0, opacity: 0.7 }}>The gate cannot reach the hound's record.</p>}

          {state && (
            <>
              <p style={{ margin: '0 0 8px' }}>
                {state.paused
                  ? 'PAUSED — the senses are stopped and nothing is judged.'
                  : state.silent
                    ? `SILENT — no heartbeat for ${state.heartbeatAgeSeconds < 0 ? 'ever' : `${state.heartbeatAgeSeconds}s`}. A stopped hound is a finding.`
                    : `Listening. Last beat ${state.heartbeatAgeSeconds}s ago.`}
              </p>
              <p style={{ margin: '0 0 8px', opacity: 0.75 }}>
                {state.findings} findings seen · {state.judged} judged · CRITICAL {state.bySeverity.CRITICAL ?? 0} ·
                {' '}HIGH {state.bySeverity.HIGH ?? 0} · MEDIUM {state.bySeverity.MEDIUM ?? 0}
              </p>
              {state.newest.length === 0 && <p style={{ margin: 0, opacity: 0.7 }}>Nothing above MEDIUM has been judged yet.</p>}
              <ul style={{ margin: 0, padding: 0, listStyle: 'none', maxHeight: 260, overflowY: 'auto' }}>
                {state.newest.map((row, i) => (
                  <li key={`${row.ts}-${i}`} style={{ padding: '6px 0', borderTop: '1px solid var(--ymir-line, #222)' }}>
                    <div style={{ display: 'flex', gap: 8 }}>
                      <span style={{
                        fontWeight: 600,
                        color: row.severity === 'CRITICAL' ? '#e5484d' : '#e2a336',
                      }}>{row.severity}</span>
                      <span style={{ opacity: 0.6 }}>{row.ts}</span>
                    </div>
                    <div>{row.line}</div>
                    {row.reasoning && (
                      <div style={{ opacity: 0.7 }}>
                        ↳ {row.reasoning.rung}/{row.reasoning.model}
                      </div>
                    )}
                  </li>
                ))}
              </ul>
              <p style={{ margin: '10px 0 0', opacity: 0.6 }}>
                Pause or resume: <code>bin/ward/garmr.sh pause|resume</code>
              </p>
            </>
          )}
        </div>
      )}
    </div>
  );
}

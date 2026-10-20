import { useCallback, useEffect, useRef, useState } from 'react';
import { Terminal as XTerm, type ITheme } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import { WebLinksAddon } from '@xterm/addon-web-links';
import '@xterm/xterm/css/xterm.css';

/**
 * Þráðr — the terminal view (plan 93).
 *
 * A REAL shell, not a picture of one: the emulator is xterm.js (the component VS Code
 * uses) and the other end is a pty on the gate, so `herdr`, `vim` and anything else with
 * a TTY behaves exactly as it does in a terminal window.
 *
 * Three laws are visible in this file:
 *
 *   · the colour comes from the app's own CSS variables, so the terminal wears the same
 *     ember cloth as the rest of the high seat instead of a foreign palette;
 *   · the SOCKET owns the shell — unmount closes it, and the gate kills the pty on close,
 *     so a closed tab is never a shell running unattended;
 *   · a refusal is SHOWN, never swallowed: if the gate says no (not signed in, loopback
 *     only, terminals disabled), the panel says which, because a blank black rectangle is
 *     indistinguishable from a hang.
 */

type Status = { state: 'connecting' | 'live' | 'closed' | 'refused'; detail?: string };

function theme(): ITheme {
  const css = getComputedStyle(document.documentElement);
  const v = (name: string, fallback: string) => css.getPropertyValue(name).trim() || fallback;
  const bg = v('--bg', v('--color-app', '#0b0b0c'));
  const fg = v('--fg', v('--color-text', '#d8d8d8'));
  return {
    background: bg,
    foreground: fg,
    cursor: fg,
    cursorAccent: bg,
    selectionBackground: v('--ember', '#e68e0d') + '44',
    black: '#1b1b1f', red: '#e06c75', green: '#98c379', yellow: '#e5c07b',
    blue: '#61afef', magenta: '#c678dd', cyan: '#56b6c2', white: '#dcdfe4',
    brightBlack: '#5c6370', brightRed: '#ef7b85', brightGreen: '#a9d17f',
    brightYellow: '#f0cd8c', brightBlue: '#7cc0f5', brightMagenta: '#d79ae8',
    brightCyan: '#6fc8d4', brightWhite: '#ffffff',
  };
}

export function Terminal({
  cwd,
  onStatus,
  autoCommand,
}: {
  cwd?: string;
  onStatus?: (s: Status) => void;
  /** Type this into the shell once it is live (e.g. `herdr`). */
  autoCommand?: string;
}) {
  const hostRef = useRef<HTMLDivElement | null>(null);
  const termRef = useRef<XTerm | null>(null);
  const fitRef = useRef<FitAddon | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const [status, setStatus] = useState<Status>({ state: 'connecting' });
  const [ready, setReady] = useState<{ shell?: string; cwd?: string; pid?: number }>({});

  const set = useCallback(
    (s: Status) => {
      setStatus(s);
      onStatus?.(s);
    },
    [onStatus],
  );

  useEffect(() => {
    const host = hostRef.current;
    if (!host) return;

    const term = new XTerm({
      theme: theme(),
      fontFamily:
        getComputedStyle(document.documentElement).getPropertyValue('--mono').trim() ||
        'ui-monospace, SFMono-Regular, Menlo, monospace',
      fontSize: 13,
      lineHeight: 1.25,
      cursorBlink: true,
      convertEol: true,
      scrollback: 5000,
      allowProposedApi: true,
    });
    const fit = new FitAddon();
    term.loadAddon(fit);
    term.loadAddon(new WebLinksAddon());
    term.open(host);
    try {
      fit.fit();
    } catch {
      /* a hidden host has no size yet; the observer will fit it */
    }
    termRef.current = term;
    fitRef.current = fit;

    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    const params = new URLSearchParams({ cols: String(term.cols), rows: String(term.rows) });
    if (cwd) params.set('cwd', cwd);
    const ws = new WebSocket(`${proto}://${location.host}/api/terminal?${params.toString()}`);
    wsRef.current = ws;

    const sendResize = () => {
      if (ws.readyState !== WebSocket.OPEN) return;
      try {
        fit.fit();
      } catch {
        return;
      }
      ws.send(JSON.stringify({ t: 'r', cols: term.cols, rows: term.rows }));
    };

    ws.onopen = () => set({ state: 'live' });
    ws.onmessage = (ev) => {
      let msg: { t?: string; d?: string; m?: string; shell?: string; cwd?: string; pid?: number; code?: number };
      try {
        msg = JSON.parse(String(ev.data));
      } catch {
        return;
      }
      if (msg.t === 'o' && typeof msg.d === 'string') term.write(msg.d);
      else if (msg.t === 'ready') {
        setReady({ shell: msg.shell, cwd: msg.cwd, pid: msg.pid });
        if (autoCommand) ws.send(JSON.stringify({ t: 'i', d: `${autoCommand}\r` }));
      } else if (msg.t === 'error') set({ state: 'refused', detail: msg.m });
      else if (msg.t === 'exit') {
        term.write(`\r\n\x1b[2m[shell exited${msg.code !== undefined ? ` (${msg.code})` : ''}]\x1b[0m\r\n`);
        set({ state: 'closed', detail: `exit ${msg.code ?? '?'}` });
      }
    };
    ws.onclose = () => set({ state: 'closed', detail: 'connection closed' });
    ws.onerror = () => set({ state: 'refused', detail: 'the gate refused the socket' });

    const dataSub = term.onData((d) => {
      if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ t: 'i', d }));
    });

    const ro = new ResizeObserver(() => sendResize());
    ro.observe(host);
    window.addEventListener('resize', sendResize);

    return () => {
      window.removeEventListener('resize', sendResize);
      ro.disconnect();
      dataSub.dispose();
      // Closing the socket is what kills the shell: the gate owns that law, not the UI.
      try {
        ws.close();
      } catch {
        /* already gone */
      }
      term.dispose();
      termRef.current = null;
      fitRef.current = null;
      wsRef.current = null;
    };
  }, [cwd, autoCommand, set]);

  return (
    <div className="thradr-terminal">
      <div className="thradr-bar">
        <span className={`thradr-pill ${status.state}`}>{status.state}</span>
        <span className="thradr-meta">
          {ready.shell ? `${ready.shell}` : 'shell'} {ready.cwd ? `· ${ready.cwd}` : ''}
          {ready.pid ? ` · pid ${ready.pid}` : ''}
        </span>
        <button
          type="button"
          className="thradr-btn"
          onClick={() => {
            const t = termRef.current;
            if (!t) return;
            const ws = wsRef.current;
            t.clear();
            if (ws && ws.readyState === WebSocket.OPEN) {
              fitRef.current?.fit();
              ws.send(JSON.stringify({ t: 'r', cols: t.cols, rows: t.rows }));
            }
          }}
        >
          clear
        </button>
      </div>
      {status.state === 'refused' && (
        <div className="thradr-refused">{status.detail ?? 'the gate refused the terminal'}</div>
      )}
      <div className="thradr-host" ref={hostRef} />
    </div>
  );
}

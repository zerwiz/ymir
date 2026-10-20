import { useEffect, useState } from 'react';
import { Terminal } from '../components/Terminal';

/**
 * Þráðr — the terminal gate (plan 93).
 *
 * The point of this gate is not to be a terminal widget: it is that `herdr` can be opened
 * INSIDE the high seat, in a real pty, with its panes and its agents — the operator keeps
 * the tool they already use instead of learning a second one.
 *
 * Two quick actions, because they are what the gate is for:
 *   · "herdr"        attach to the herdr session (the real TUI)
 *   · "herdr agents" list who stands before attaching
 *
 * The status strip names the seat's own truth — enabled or not, loopback-only or not, the
 * shell it will open — because a terminal that fails must fail out loud.
 */

interface TerminalStatus {
  enabled: boolean;
  remoteAllowed: boolean;
  shell: string;
  cwd: string;
  open: number;
  maxPerUser: number;
  idleTimeoutMs: number;
}

export function Thradr() {
  const [status, setStatus] = useState<TerminalStatus | null>(null);
  const [problem, setProblem] = useState<string | null>(null);
  const [command, setCommand] = useState<string | undefined>(undefined);
  const [run, setRun] = useState(0);

  useEffect(() => {
    let alive = true;
    fetch('/api/terminal/status', { credentials: 'same-origin' })
      .then(async (r) => {
        if (!r.ok) throw new Error(`terminal status ${r.status}`);
        return (await r.json()) as TerminalStatus;
      })
      .then((s) => alive && setStatus(s))
      .catch((e: unknown) => alive && setProblem(e instanceof Error ? e.message : String(e)));
    return () => {
      alive = false;
    };
  }, []);

  return (
    <div className="thradr">
      <div className="thradr-head">
        <div>
          <div className="thradr-title">Þráðr</div>
          <div className="thradr-sub">
            a real shell in the high seat — the thread you pull into the machine
          </div>
        </div>
        <div className="thradr-actions">
          <button
            type="button"
            className="thradr-btn primary"
            onClick={() => {
              setCommand('herdr');
              setRun((n) => n + 1);
            }}
          >
            open herdr
          </button>
          <button
            type="button"
            className="thradr-btn"
            onClick={() => {
              setCommand('herdr agent list');
              setRun((n) => n + 1);
            }}
          >
            who stands
          </button>
          <button
            type="button"
            className="thradr-btn"
            onClick={() => {
              setCommand(undefined);
              setRun((n) => n + 1);
            }}
          >
            plain shell
          </button>
        </div>
      </div>

      {problem && <div className="thradr-error">{problem}</div>}

      {status && (
        <div className="thradr-status">
          <span className={status.enabled ? 'ok' : 'bad'}>
            {status.enabled ? 'enabled' : 'disabled (YMIR_TERMINAL=0)'}
          </span>
          <span>{status.remoteAllowed ? 'remote allowed' : 'loopback only'}</span>
          <span>shell {status.shell}</span>
          <span>cwd {status.cwd}</span>
          <span>
            open {status.open}/{status.maxPerUser}
          </span>
          <span>idle close {Math.round(status.idleTimeoutMs / 60000)} min</span>
        </div>
      )}

      {/* `run` is the key: a new quick action remounts the terminal, which opens a new
          socket and therefore a new shell (the old one dies with its socket). */}
      <Terminal key={run} autoCommand={command} />
    </div>
  );
}

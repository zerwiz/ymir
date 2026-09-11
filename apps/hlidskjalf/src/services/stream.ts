import { useYmir } from '../state/store';
import type { StreamEvent } from '../types';

/**
 * Stream transport.
 *
 * In production this opens `GET /api/stream` (SSE) with a fallback to
 * `WS /api/tasks/:id`. Until the ymir-gate backend (W0027) is raised, this
 * synthesises live Ratatoskr + Runes traffic from the local store so the
 * forge looks hot. Swap `MOCK` to false once the gate answers.
 */

const AGENTS = ['Brokk', 'Kaia', 'Eindri-01', 'Eindri-02', 'Eindri-03', 'Eindri-04'];
const MODULES = ['hlidskjalf', 'mimirsbrunn', 'ratatoskr', 'utgard', 'yggdrasil', 'runes', 'valhalla'];
const MESSAGES = [
  'recall hybrid — episodes merged',
  'worktree branch advanced',
  'card signature verified',
  'task state announced to peers',
  'observe episode carved into the well',
  'checksum chain extended',
  'redis queue drained group ratatoskr:inbox',
  'veil verdict grounded',
];

let timer: number | undefined;
let counter = 0;

function jitter<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function synth(): StreamEvent {
  counter += 1;
  const kind = Math.random() > 0.45 ? 'ratatoskr' : 'rune';
  const from = jitter(AGENTS);
  const checksum = Math.random().toString(16).slice(2, 8);
  return {
    id: `live-${Date.now()}-${counter}`,
    ts: new Date().toISOString(),
    kind,
    from,
    to: kind === 'ratatoskr' ? jitter(AGENTS) : undefined,
    state: kind === 'ratatoskr' ? 'WORKING' : undefined,
    module: jitter(MODULES),
    message: jitter(MESSAGES),
    checksum,
  };
}

export function startStream(): () => void {
  // Demo mode keeps the synthetic stream; live mode tails real Runes over SSE.
  if (useYmir.getState().demo) {
    timer = window.setInterval(() => {
      const { streamPaused, pushStream, traceability } = useYmir.getState();
      if (streamPaused) return;
      pushStream(synth());
      // Let the live index breathe around its target (0.984).
      const drift = (Math.random() - 0.5) * 0.002;
      const next = Math.min(0.999, Math.max(0.95, traceability + drift));
      useYmir.setState({ traceability: Number(next.toFixed(3)) });
    }, 2600);
    return () => window.clearInterval(timer);
  }

  const base = (import.meta.env.VITE_API_URL as string | undefined) ?? '';
  const source = new EventSource(`${base}/api/stream`);
  source.onmessage = (e) => {
    try {
      useYmir.getState().pushStream(JSON.parse(e.data) as StreamEvent);
    } catch {
      /* ignore malformed frame */
    }
  };
  return () => source.close();
}

import { useYmir } from '../state/store';
import type { StreamEvent } from '../types';

/**
 * Stream transport — real only.
 *
 * One source: live Runes over SSE (`GET /api/stream`), routed to the page by
 * module. There is no synthetic feed and no seeded narration; a quiet system
 * shows a quiet stream.
 */
export function startStream(): () => void {
  if (useYmir.getState().demo) return () => {};

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

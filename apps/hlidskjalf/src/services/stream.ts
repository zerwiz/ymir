import { useYmir } from '../state/store';
import type { StreamEvent } from '../types';

/**
 * Stream transport — live Runes over SSE (`GET /api/stream`), routed to their
 * page by module. The stream carries only real events; nothing is synthesized.
 */

let started = false;

export function startStream(): () => void {
  if (started) return () => {};
  started = true;

  let close = () => {};
  if (!useYmir.getState().demo) {
    const base = (import.meta.env.VITE_API_URL as string | undefined) ?? '';
    const source = new EventSource(`${base}/api/stream`);
    source.onmessage = (e) => {
      try {
        useYmir.getState().pushStream(JSON.parse(e.data) as StreamEvent);
      } catch {
        /* ignore malformed frame */
      }
    };
    close = () => source.close();
  }

  return () => {
    close();
    started = false;
  };
}

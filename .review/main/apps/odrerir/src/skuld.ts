// skuld.ts — the hall's book over the Skuld MCP (the tickets hall, plan 43).
//
// The door is the TAILNET MagicDNS name — the 2026-09-24 law: a fleet MCP is
// addressed by tailnet name, never a LAN IP (a LAN address draws HTTP 000 from
// the other seats; the MagicDNS name handshakes 200). Skuld serves the fleet
// tickets + plans tools: tickets/list|get|create|update, comments/list|post,
// plans/list|get|create. The client mirrors the hall's old faithful wire
// (HTTP JSON-RPC with an mcp-session-id header), just carried into the new
// React shell.
//
// CONNECTION IS VISIBLE (2026-09-24): the user must know whether the book is
// connected, or why it is not. Every init/call publishes a status
// (idle | connecting | connected | error) that the boards render as a chip,
// with a retry that clears the session and rings again.
export const SKULD_URL =
  (import.meta.env.VITE_SKULD_URL as string | undefined) ??
  'http://whynot.tailefab81.ts.net:8320';

export type SkuldState = 'idle' | 'connecting' | 'connected' | 'error';
export interface SkuldStatus {
  state: SkuldState;
  detail: string;
  at: number;
}

let sessionId = '';
let status: SkuldStatus = { state: 'idle', detail: 'not yet asked', at: Date.now() };
const watchers = new Set<(s: SkuldStatus) => void>();

function publish(state: SkuldState, detail: string) {
  status = { state, detail, at: Date.now() };
  for (const w of watchers) w(status);
}

export function skuldStatus(): SkuldStatus {
  return status;
}

export function onSkuldStatus(cb: (s: SkuldStatus) => void): () => void {
  watchers.add(cb);
  cb(status);
  return () => watchers.delete(cb);
}

async function post(body: unknown): Promise<Record<string, unknown>> {
  const headers: Record<string, string> = {
    'content-type': 'application/json',
    accept: 'application/json, text/event-stream',
  };
  if (sessionId) headers['mcp-session-id'] = sessionId;
  const r = await fetch(SKULD_URL, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  // Skuld answers tools/call as an SSE stream (event: message + a data: JSON
  // frame) even when JSON would do — a r.json() would THROW and the book read
  // empty (the 2026-09-24 alignment find). Parse the last data: frame when the
  // body is a stream, plain JSON otherwise.
  const text = await r.text();
  const dataLine = text.split('\n').filter((l) => l.startsWith('data:')).pop();
  const payload = dataLine ? dataLine.slice(5).trim() : text.trim();
  return (JSON.parse(payload || '{}') as Record<string, unknown>) ?? {};
}

export async function skuldInit(): Promise<void> {
  if (sessionId) return;
  publish('connecting', SKULD_URL);
  try {
    const h = await fetch(SKULD_URL, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        accept: 'application/json, text/event-stream',
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: 1,
        method: 'initialize',
        params: {
          protocolVersion: '2025-06-18',
          capabilities: {},
          clientInfo: { name: 'odrerir-hall', version: '2' },
        },
      }),
      signal: AbortSignal.timeout(8000),
    });
    if (!h.ok) throw new Error(`HTTP ${h.status}`);
    sessionId = h.headers.get('mcp-session-id') ?? '';
    publish('connected', sessionId ? `session ${sessionId.slice(0, 8)}` : 'connected (no session id)');
  } catch (e) {
    sessionId = '';
    publish('error', e instanceof Error ? e.message : String(e));
    throw e;
  }
}

/** Ring the door again after a failure (the chip's retry). */
export async function skuldReconnect(): Promise<void> {
  sessionId = '';
  await skuldInit();
}

export async function skuldCall(name: string, args: Record<string, unknown>): Promise<string> {
  try {
    await skuldInit();
    const d = await post({
      jsonrpc: '2.0',
      id: Date.now(),
      method: 'tools/call',
      params: { name, arguments: args },
    });
    const result = d.result as { content?: { text?: string }[] } | undefined;
    const text =
      result?.content?.[0]?.text ??
      (d.error as { message?: string } | undefined)?.message ??
      'silence';
    publish('connected', `${name} answered`);
    return text;
  } catch (e) {
    publish('error', `${name}: ${e instanceof Error ? e.message : String(e)}`);
    throw e;
  }
}
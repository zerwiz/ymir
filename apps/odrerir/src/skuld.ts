// skuld.ts — the hall's book over the Skuld MCP (the tickets hall, plan 43).
//
// The door is the TAILNET MagicDNS name — the 2026-09-24 law: a fleet MCP is
// addressed by tailnet name, never a LAN IP (a LAN address draws HTTP 000 from
// the other seats; the MagicDNS name handshakes 200). Skuld serves the fleet
// tickets + plans tools: tickets/list|get|create|update, comments/list|post,
// plans/list|get|create. The client mirrors the hall's old faithful wire
// (HTTP JSON-RPC with an mcp-session-id header), just carried into the new
// React shell.
const SKULD_URL =
  (import.meta.env.VITE_SKULD_URL as string | undefined) ??
  'http://whynot.tailefab81.ts.net:8320';

let sessionId = '';

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
  return (await r.json()) as Record<string, unknown>;
}

export async function skuldInit(): Promise<void> {
  if (sessionId) return;
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
  });
  sessionId = h.headers.get('mcp-session-id') ?? '';
}

export async function skuldCall(name: string, args: Record<string, unknown>): Promise<string> {
  const d = await post({
    jsonrpc: '2.0',
    id: Date.now(),
    method: 'tools/call',
    params: { name, arguments: args },
  });
  const result = d.result as { content?: { text?: string }[] } | undefined;
  return (
    result?.content?.[0]?.text ??
    (d.error as { message?: string } | undefined)?.message ??
    'silence'
  );
}
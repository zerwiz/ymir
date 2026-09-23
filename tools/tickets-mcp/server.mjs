#!/usr/bin/env node
// skuld (tickets-mcp) — the ticket hall: Ymir's tickets and plans, served as
// an MCP stdio server for mcp-proxy on :8320. The store is the heart's
// postgres (`skuld` db; the skuld role). Deps-free: psql only (PGPASSWORD).
//
// THE BLOCKING LAW (the Allfather's decree, from the wayofteams guardrail):
// an agent that does not make tickets and plans in the correct way is BLOCKED.
// The shape's law: a registered namespace; a ticket needs a real title (>= 4),
// a real description (>= 10), a valid priority, <= 6 labels; a plan needs body
// >= 40 and its tickets[] must all exist in the namespace. First violation =
// a warning on the blocks ledger; at SKULD_TOLERANCE violations the agent is
// hard-blocked (every skuld tool isError "blocked: <reason>") until the
// operator clears (blocks/clear, open only to SKULD_OPERATOR) or the ledger
// is amended. Statuses walk forward: open -> in-progress -> review -> closed
// (closed is terminal).

import { spawnSync } from 'node:child_process';

const DB = process.env.SKULD_PGHOST || '127.0.0.1';
const ROLE = process.env.SKULD_PGROLE || 'skuld';
const PASS = process.env.SKULD_PGPASSWORD || 'skuld';
const DBN  = process.env.SKULD_DBNAME || 'skuld';
const OPER = process.env.SKULD_OPERATOR || 'brokk';
const TOLERANCE = parseInt(process.env.SKULD_TOLERANCE || '1', 10);
const PROTOCOL = '2025-06-18';
const PRIORITIES = ['Low', 'Medium', 'High', 'Critical'];
const STATUSES = ['open', 'in-progress', 'review', 'closed'];
const NEXT = { open: ['in-progress'], 'in-progress': ['review'], review: ['closed'], closed: [] };

function q(sql, vars) {
  // psql -c never resolves :'var' (proven), so the markers are inlined as
  // escaped literals ('' doubling = injection-safe text substitution).
  const out = sql.replace(/:'([a-z_]+)'/g, (m, k) => "'" + String(vars?.[k] ?? '').replace(/'/g, "''") + "'");
  const r = spawnSync('psql', ['-h', DB, '-U', ROLE, '-d', DBN, '-Atc', out],
    { env: { ...process.env, PGPASSWORD: PASS }, encoding: 'utf8', maxBuffer: 8 << 20 });
  return { ok: r.status === 0, out: (r.stdout || '').trim(), err: (r.stderr || '').trim() };
}

function rows(out) { return out ? out.split('\n') : []; }

let CURRENT_AGENT = 'unknown';   // per-session, caught at the initialize
const SESSIONS = new Map();      // sid -> { agent, at }

function agentOf() { return CURRENT_AGENT; }

// — the block ledger —
function violation(agent, reason) {
  // one warning: the first attempt already fails (isError); the ledger counts.
  q(`INSERT INTO blocks (agent, reason) VALUES (:'a', :'r')
     ON CONFLICT (agent) DO UPDATE SET reason = :'r', created_at = now()`, { a: agent, r: reason });
}
function blockStatus(agent) {
  const r = q(`SELECT reason, created_at FROM blocks WHERE agent = :'a'`, { a: agent });
  return rows(r.out)[0] || null;
}
function isBlocked(agent) {
  const b = blockStatus(agent);
  if (!b) return null;
  const [reason] = b.split('|');
  return reason;
}

function ensureNamespace(ns) {
  const r = q(`SELECT 1 FROM namespaces WHERE name = :'n'`, { n: ns });
  return rows(r.out).length > 0;
}

const law = {
  ticket(ns, title, description, priority, labels) {
    if (!ns || !ensureNamespace(ns)) return `namespace '${ns}' is not on the registry (registered: ymir, whynotproductions)`;
    if (!title || String(title).trim().length < 4) return 'a ticket needs a real title (4+ chars)';
    if (!description || String(description).trim().length < 10) return 'a ticket needs a real description (10+ chars)';
    if (!PRIORITIES.includes(priority)) return `priority must be one of ${PRIORITIES.join(', ')}`;
    if (labels.length > 6) return 'a ticket may carry at most 6 labels';
    return null;
  },
  plan(ns, title, body, tickets) {
    if (!ensureNamespace(ns)) return `namespace '${ns}' is not on the registry`;
    if (!title || String(title).trim().length < 6) return 'a plan needs a real title (6+ chars)';
    if (!body || String(body).trim().length < 40) return 'a plan needs a real body (40+ chars) — anything plan-sized is written first';
    if (tickets.length) {
      const t = q(`SELECT id FROM tickets WHERE namespace = :'n' AND id = ANY (string_to_array(:'ts', ',')::bigint[])`, { n: ns, ts: tickets.join(',') });
      const found = rows(t.out).length;
      if (found !== tickets.length) return `plan tickets must exist in the namespace (${found}/${tickets.length} found)`;
    }
    return null;
  },
  transition(cur, to) {
    if (!STATUSES.includes(to)) return `status must be one of ${STATUSES.join(', ')}`;
    if (to === cur) return null;
    if (!(NEXT[cur] || []).includes(to)) return `illegal status walk: ${cur} -> ${to} (forward only; closed is terminal)`;
    return null;
  }
};

function blockedResult(agent) {
  const reason = isBlocked(agent);
  const error = reason ? `blocked: ${reason} — an agent that does not make tickets and plans correctly is blocked; the operator clears it (blocks/clear)` : null;
  return { error, reason };
}

const rpc = {
  initialize: (p) => {
    if (p?.clientInfo?.name) CURRENT_AGENT = String(p.clientInfo.name).slice(0, 64);
    return { protocolVersion: p?.protocolVersion || PROTOCOL,
    capabilities: { tools: { listChanged: false }, resources: { listChanged: false, subscribe: false } },
    serverInfo: { name: 'skuld', version: '1' } };
  },
  'tools/list': () => ({ tools: [
    { name: 'tickets/create', description: 'Create a ticket in a registered namespace (title 4+, description 10+, priority Low/Medium/High/Critical, <= 6 labels). The blocking law is on: a malformed ticket blocks the calling agent.', inputSchema: { type: 'object', properties: { namespace: { type: 'string' }, title: { type: 'string' }, description: { type: 'string' }, priority: { type: 'string' }, labels: { type: 'array', items: { type: 'string' } } }, required: ['namespace', 'title', 'description'] } },
    { name: 'tickets/list', description: 'List tickets (by namespace, status, assignee, owner).', inputSchema: { type: 'object', properties: { namespace: { type: 'string' }, status: { type: 'string' }, assignee: { type: 'string' }, owner: { type: 'string' } } } },
    { name: 'tickets/get', description: 'Read one ticket by id.', inputSchema: { type: 'object', properties: { id: { type: 'integer' } }, required: ['id'] } },
    { name: 'tickets/update', description: 'Update a ticket: status (open -> in-progress -> review -> closed, forward only), priority, labels, assignee.', inputSchema: { type: 'object', properties: { id: { type: 'integer' }, status: { type: 'string' }, priority: { type: 'string' }, labels: { type: 'array', items: { type: 'string' } }, assignee: { type: 'string' } }, required: ['id'] } },
    { name: 'tickets/close', description: 'Close a ticket (terminal; only from review).', inputSchema: { type: 'object', properties: { id: { type: 'integer' } }, required: ['id'] } },
    { name: 'plans/create', description: 'Create a plan (title 6+, body 40+; tickets[] must all exist in the namespace). The blocking law is on.', inputSchema: { type: 'object', properties: { namespace: { type: 'string' }, title: { type: 'string' }, body: { type: 'string' }, tickets: { type: 'array', items: { type: 'integer' } } }, required: ['namespace', 'title', 'body'] } },
    { name: 'plans/list', description: 'List plans (by namespace).', inputSchema: { type: 'object', properties: { namespace: { type: 'string' } } } },
    { name: 'blocks/status', description: 'The calling agent\'s block status.', inputSchema: { type: 'object' } },
    { name: 'blocks/clear', description: 'Clear an agent\'s block (the operator\'s door only — agent must equal SKULD_OPERATOR).', inputSchema: { type: 'object', properties: { agent: { type: 'string' } }, required: ['agent'] } }
  ] }),
  'tools/call': (p, agent) => {
    const name = p?.name || '';
    const args = p?.arguments || {};
    // the operator's door never blocks
    if (name === 'blocks/clear') {
      const target = String(args.agent || '');
      if (CURRENT_AGENT !== OPER) return { content: [{ type: 'text', text: `blocks/clear is the operator's door (SKULD_OPERATOR=${OPER}); you are ${CURRENT_AGENT}` }], isError: true };
      q(`DELETE FROM blocks WHERE agent = :'a'`, { a: target });
      return { content: [{ type: 'text', text: `block cleared for ${target}` }] };
    }
    if (name === 'blocks/status') {
      const b = blockStatus(agent);
      return { content: [{ type: 'text', text: b ? `blocked: ${b.split('|')[0]}` : `clean: ${agent}` }] };
    }
    // the wall: a blocked agent cannot touch the hall's books
    const { error } = blockedResult(agent);
    if (error && name.startsWith('tickets') === false && name.startsWith('plans') === false) {}
    if (error) return { content: [{ type: 'text', text: error }], isError: true };

    if (name === 'tickets/create') {
      const ns = String(args.namespace || ''); const title = String(args.title || '');
      const body = String(args.description || ''); const pri = String(args.priority || 'Medium');
      const labels = Array.isArray(args.labels) ? args.labels.map(String) : [];
      const bad = law.ticket(ns, title, body, pri, labels);
      if (bad) { violation(agent, `tickets/create refused: ${bad}`); return { content: [{ type: 'text', text: `refused: ${bad}\n(recorded — a repeated violation blocks you)` }], isError: true }; }
      const r = q(`INSERT INTO tickets (namespace, title, description, priority, labels, owner) VALUES (:'n', :'t', :'d', :'p', string_to_array(:'l', ','), :'o') RETURNING id`, { n: ns, t: title, d: body, p: pri, l: labels.join(','), o: agent });
      if (!r.ok) return { content: [{ type: 'text', text: `store error: ${r.err}` }], isError: true };
      return { content: [{ type: 'text', text: `ticket #${r.out} created in '${ns}'` }] };
    }
    if (name === 'tickets/list') {
      const f = [];
      const v = {};
      for (const [k, col] of [['namespace', 'namespace'], ['status', 'status'], ['assignee', 'assignee'], ['owner', 'owner']]) {
        if (args[k]) { f.push(`${col} = :'${k}'`); v[k] = String(args[k]); }
      }
      const r = q(`SELECT id, namespace, status, priority, title FROM tickets ${f.length ? 'WHERE ' + f.join(' AND ') : ''} ORDER BY id DESC LIMIT 100`, v);
      return { content: [{ type: 'text', text: rows(r.out).map(x => `#${x}`).join('\n') || '(no tickets)' }] };
    }
    if (name === 'tickets/get') {
      const r = q(`SELECT id, namespace, title, description, priority, status, labels, owner, assignee, created_at FROM tickets WHERE id = :'id'`, { id: String(args.id) });
      const line = rows(r.out)[0];
      if (!line) return { content: [{ type: 'text', text: `no ticket #${args.id}` }], isError: true };
      return { content: [{ type: 'text', text: line }] };
    }
    if (name === 'tickets/update') {
      const cur = q(`SELECT status FROM tickets WHERE id = :'id'`, { id: String(args.id) });
      const curS = rows(cur.out)[0];
      if (!curS) return { content: [{ type: 'text', text: `no ticket #${args.id}` }], isError: true };
      const sets = []; const v = { id: String(args.id) };
      if (args.status !== undefined) {
        const bad = law.transition(curS, String(args.status));
        if (bad) { violation(agent, `tickets/update refused: ${bad}`); return { content: [{ type: 'text', text: `refused: ${bad}\n(recorded)` }], isError: true }; }
        sets.push(`status = :'status'`); v.status = String(args.status);
        if (args.status === 'closed') sets.push(`closed_at = now()`);
      }
      if (args.priority !== undefined) {
        if (!PRIORITIES.includes(args.priority)) return { content: [{ type: 'text', text: `priority must be one of ${PRIORITIES.join(', ')}` }], isError: true };
        sets.push(`priority = :'priority'`); v.priority = String(args.priority);
      }
      if (args.labels !== undefined) {
        const ls = Array.isArray(args.labels) ? args.labels.map(String) : [];
        if (ls.length > 6) return { content: [{ type: 'text', text: 'at most 6 labels' }], isError: true };
        sets.push(`labels = string_to_array(:'labels', ',')`); v.labels = ls.join(',');
      }
      if (args.assignee !== undefined) { sets.push(`assignee = :'assignee'`); v.assignee = String(args.assignee); }
      if (!sets.length) return { content: [{ type: 'text', text: 'nothing to update' }], isError: true };
      sets.push(`updated_at = now()`);
      const r = q(`UPDATE tickets SET ${sets.join(', ')} WHERE id = :'id' RETURNING id`, v);
      return r.ok ? { content: [{ type: 'text', text: `ticket #${r.out} updated` }] } : { content: [{ type: 'text', text: `store error: ${r.err}` }], isError: true };
    }
    if (name === 'tickets/close') {
      return rpc['tools/call']({ name: 'tickets/update', arguments: { id: args.id, status: 'closed' } }, agent);
    }
    if (name === 'plans/create') {
      const ns = String(args.namespace || ''); const title = String(args.title || '');
      const body = String(args.body || ''); const ts = Array.isArray(args.tickets) ? args.tickets.map(x => String(x)) : [];
      const bad = law.plan(ns, title, body, ts);
      if (bad) { violation(agent, `plans/create refused: ${bad}`); return { content: [{ type: 'text', text: `refused: ${bad}\n(recorded — a repeated violation blocks you)` }], isError: true }; }
      const r = q(`INSERT INTO plans (namespace, title, body, tickets, status) VALUES (:'n', :'t', :'d', string_to_array(:'ts', ',')::bigint[], 'active') RETURNING id`, { n: ns, t: title, d: body, ts: ts.join(',') });
      return r.ok ? { content: [{ type: 'text', text: `plan #${r.out} created in '${ns}'` }] } : { content: [{ type: 'text', text: `store error: ${r.err}` }], isError: true };
    }
    if (name === 'plans/list') {
      const f = args.namespace ? `WHERE namespace = :'n'` : '';
      const v = args.namespace ? { n: String(args.namespace) } : {};
      const r = q(`SELECT id, namespace, status, tickets, title FROM plans ${f} ORDER BY id DESC LIMIT 50`, v);
      return { content: [{ type: 'text', text: rows(r.out).map(x => `#${x}`).join('\n') || '(no plans)' }] };
    }
    return { content: [{ type: 'text', text: `unknown tool: ${name}` }], isError: true };
  },
  'resources/list': () => ({
    resources: [
      { uri: 'skuld://book', name: 'the ticket book', description: 'tickets and plans of the hall', mimeType: 'text/plain' }
    ]
  }),
  'resources/read': (p) => {
    const id = (p?.uri || '').replace(/^skuld:\/\/\w+[#/]?/, '');
    if (id === 'book') {
      const t = q(`SELECT count(*) FROM tickets`); const pl = q(`SELECT count(*) FROM plans`);
      return { contents: [{ uri: p.uri, mimeType: 'text/plain', text: `tickets: ${rows(t.out)[0] || 0} · plans: ${rows(pl.out)[0] || 0}` }] };
    }
    const r = q(`SELECT id, namespace, title, description, priority, status, labels, owner, assignee FROM tickets WHERE id = :'id'`, { id });
    const line = rows(r.out)[0];
    return { contents: [{ uri: p.uri, mimeType: 'text/plain', text: line ? `#${line}` : 'no such ticket' }] };
  }
};

function handle(msg) {
  const { id, method, params } = msg;
  if (!method || method === 'notifications/initialized' || method.startsWith('notifications/')) return null;
  let result = null, error = null;
  try {
    if (method === 'initialize') { if (params?.clientInfo?.name) CURRENT_AGENT = String(params.clientInfo.name).slice(0, 64); result = rpc.initialize(params); }
    else if (method === 'tools/list') result = rpc['tools/list']();
    else if (method === 'tools/call') result = rpc['tools/call'](params, CURRENT_AGENT);
    else if (method === 'resources/list') result = rpc['resources/list']();
    else if (method === 'resources/read') result = rpc['resources/read'](params);
    else error = { code: -32601, message: `Unknown method: ${method}` };
  } catch (e) { error = { code: -32603, message: String(e) }; }
  const resp = { jsonrpc: '2.0', id: id ?? null, ...(error ? { error } : { result }) };
  return { resp, agent: CURRENT_AGENT, initialized: method === 'initialize' };
}

// — the served mode: the hall speaks HTTP directly (no proxy, no identity theft) —
const PORT = parseInt(process.env.PORT || '0', 10);
if (PORT > 0) {
  import('node:http').then(({ default: http }) => {
    const server = http.createServer((req, res) => {
      const cors = { 'access-control-allow-origin': '*', 'access-control-allow-headers': 'content-type, accept, mcp-session-id, mcp-session-id', 'access-control-allow-methods': 'POST, OPTIONS' };
      if (req.method === 'OPTIONS') { res.writeHead(204, cors).end(); return; }
      if (req.method !== 'POST') { res.writeHead(405).end(); return; }
      let body = '';
      req.on('data', c => { body += c; if (body.length > 1 << 20) req.destroy(); });
      req.on('end', () => {
        let msg; try { msg = JSON.parse(body); } catch { res.writeHead(400, { 'content-type': 'application/json' }).end('{"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"parse error"}}'); return; }
        const sid = String(req.headers['mcp-session-id'] || '');
        if (!msg.method?.startsWith('notifications/') && sid && SESSIONS.has(sid)) CURRENT_AGENT = SESSIONS.get(sid).agent;
        const out = handle(msg);
        if (!out) { res.writeHead(204).end(); return; }
        let sid2 = sid;
        if (out.initialized) { sid2 = Math.random().toString(16).slice(2); SESSIONS.set(sid2, { agent: out.agent, at: Date.now() }); }
        res.writeHead(200, { 'content-type': 'application/json', ...cors, 'mcp-session-id': sid2, 'Mcp-Session-Id': sid2 });
        res.end(JSON.stringify(out.resp) + '\n');
      });
    });
    server.listen(PORT, '0.0.0.0', () => {});
    setInterval(() => { for (const [k, v] of SESSIONS) if (Date.now() - v.at > 3600e3) SESSIONS.delete(k); }, 3600e3);
  }).catch(e => { process.stderr.write(String(e)); });
}

// — the stdio mode (local pipes and tests) —
let buf = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => {
  buf += chunk;
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
    if (!line) continue;
    let msg; try { msg = JSON.parse(line); } catch { continue; }
    const out = handle(msg);
    if (out) process.stdout.write(JSON.stringify(out.resp) + '\n');
  }
});
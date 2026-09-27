#!/usr/bin/env node
// skills-mcp — the skills well: Ymir's .agents/skills served as an MCP
// stdio server (resources + a load_skill tool), for mcp-proxy to wrap and the
// fleet to serve on :8319. Every body then loads any skill on demand from the
// heart, so the master tree is always the seat's source of truth.
//
// The skills mirror lives in $SKILLS_DIR (default ~/.fleet/skills — fleet-ensure
// materializes it from the repo's .agents/skills). Plain node, no deps.
//
// Wire: JSON-RPC 2.0 over stdio (the MCP 2025-06-18 shape).
//   initialize → capabilities{tools,resources}
//   tools/list, tools/call load_skill{skill}
//   resources/list    → skills://<name> (+ assets)
//   resources/read    → the SKILL.md or an asset by uri

import fs from 'node:fs';
import path from 'node:path';

const SKILLS_DIR = process.env.SKILLS_DIR || path.join(process.env.HOME || '.', '.fleet', 'skills');
const PROTOCOL = '2025-06-18';
const VERSION = '1';

function skillsList() {
  try {
    return fs.readdirSync(SKILLS_DIR)
      .filter(n => fs.statSync(path.join(SKILLS_DIR, n)).isDirectory()
                && fs.existsSync(path.join(SKILLS_DIR, n, 'SKILL.md')))
      .sort();
  } catch { return []; }
}

function skillDescription(name) {
  try {
    const md = fs.readFileSync(path.join(SKILLS_DIR, name, 'SKILL.md'), 'utf8');
    const m = md.match(/<description>([^<]+)<\/description>/s) || md.match(/^#\s*(.+)$/m);
    return (m ? m[1] : '').trim().slice(0, 300);
  } catch { return ''; }
}

function readSkillFile(name, rel) {
  const base = path.join(SKILLS_DIR, name);
  const p = path.normalize(path.join(base, rel || 'SKILL.md'));
  if (!p.startsWith(base + path.sep) && p !== base) return null;   // traversal guard
  try { return fs.readFileSync(p, 'utf8'); } catch { return null; }
}

function assetUris(name) {
  const dir = path.join(SKILLS_DIR, name);
  const out = [];
  try {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (e.isFile() && e.name !== 'SKILL.md') out.push(`skills://${name}/${e.name}`);
      else if (e.isDirectory()) {
        for (const f of fs.readdirSync(path.join(dir, e.name)))
          out.push(`skills://${name}/${e.name}/${f}`);
      }
    }
  } catch {}
  return out;
}

const rpc = {
  initialize: (p) => ({ protocolVersion: p?.protocolVersion || PROTOCOL,
    capabilities: { tools: { listChanged: false }, resources: { listChanged: false, subscribe: false } },
    serverInfo: { name: 'skills-mcp', version: VERSION } }),
  'tools/list': () => ({
    tools: [{
      name: 'load_skill',
      description: 'Return a Ymir skill: its SKILL.md (router + assets index) for the named skill, e.g. galdr-ymirsystem, bragi-marketing, smidja-factory, nsr-compliance.',
      inputSchema: { type: 'object', properties: { skill: { type: 'string' } }, required: ['skill'] }
    }]
  }),
  'tools/call': (p) => {
    const name = p?.arguments?.skill || '';
    const skill = name.replace(/^skills:\/\//, '');
    if (!skillsList().includes(skill)) return { content: [{ type: 'text', text: `no such skill: ${skill}` }], isError: true };
    const md = readSkillFile(skill, 'SKILL.md') || '';
    const assets = assetUris(skill);
    const tail = assets.length ? `\n\n-- assets --\n${assets.join('\n')}` : '';
    return { content: [{ type: 'text', text: `# ${skill}\n\n${md}${tail}` }] };
  },
  'resources/list': () => ({
    resources: skillsList().map(n => ({
      uri: `skills://${n}`, name: n,
      description: skillDescription(n) || `Ymir skill ${n}`,
      mimeType: 'text/markdown'
    }))
  }),
  'resources/read': (p) => {
    const uri = p?.uri || '';
    const m = uri.match(/^skills:\/\/([^/]+)(?:\/(.+))?$/);
    if (!m) return { contents: [{ uri, mimeType: 'text/markdown', text: '' }] };
    const [, name, rel] = m;
    const text = readSkillFile(name, rel);
    if (text === null) return { contents: [{ uri, mimeType: 'text/markdown', text: `no such skill: ${name}` }] };
    return { contents: [{ uri, mimeType: rel?.endsWith('.json') ? 'application/json' : 'text/markdown', text }] };
  }
};

let buf = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => {
  buf += chunk;
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
    if (!line) continue;
    let msg; try { msg = JSON.parse(line); } catch { continue; }
    const { id, method, params } = msg;
    if (!method || method === 'notifications/initialized' || method.startsWith('notifications/')) continue;
    let result = null, error = null;
    if (rpc[method]) { try { result = rpc[method](params); } catch (e) { error = { code: -32603, message: String(e) }; } }
    else error = { code: -32601, message: `Unknown method: ${method}` };
    process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: id ?? null, ...(error ? { error } : { result }) }) + '\n');
  }
});
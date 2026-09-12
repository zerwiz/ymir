import type {
  AgentCard,
  ChatMessage,
  FileNode,
  ProcessInfo,
  PullRequest,
  RecallEpisode,
  RealmId,
  RuneEntry,
  SkillDef,
  StreamEvent,
  Task,
} from '../types';

const now = Date.now();
const iso = (offsetMs: number) => new Date(now - offsetMs).toISOString();
const min = 60_000;

export function seedAgents(realm: RealmId): AgentCard[] {
  const base: AgentCard[] = [
    {
      id: 'brokk',
      name: 'Brokk',
      role: 'Primary — the bellows',
      realm: 'way-of',
      domain: 'ymirlabs',
      status: 'nominal',
      capabilities: ['orchestration', 'code', 'marketing', 'strategy', 'life'],
      skills: ['brokk-craft', 'galdr', 'a2a-bridge', 'workspace_rag'],
      interface: { protocol: 'A2A 1.0', endpoint: 'local://brokk', signed: true },
      model: 'hermes-3-8b',
      uptime: 41 * 60 * min,
      tasksDone: 128,
      traceability: 0.984,
    },
    {
      id: 'kaia',
      name: 'Kaia',
      role: 'Orchestrator — the eye by the well',
      realm: 'way-of',
      domain: 'muninn',
      status: 'nominal',
      capabilities: ['recall', 'dispatch', 'veil', 'memory'],
      skills: ['a2a-bridge', 'tyr-check', 'workspace_rag'],
      interface: { protocol: 'A2A 1.0', endpoint: 'local://kaia', signed: true },
      model: 'hermes-3-8b',
      uptime: 41 * 60 * min,
      tasksDone: 96,
      traceability: 0.981,
    },
    {
      id: 'eindri-01',
      name: 'Eindri-01',
      role: 'Smith — frontend',
      realm: 'way-of',
      domain: 'brokkforge',
      status: 'nominal',
      capabilities: ['react', 'vite', 'design-system', 'a11y'],
      skills: ['galdr-crafter', 'galdr-compliance'],
      interface: { protocol: 'A2A 1.0', endpoint: 'utgard://eindri-01', signed: true },
      model: 'hermes-3-8b',
      uptime: 22 * min,
      tasksDone: 7,
      traceability: 0.972,
    },
    {
      id: 'eindri-02',
      name: 'Eindri-02',
      role: 'Smith — backend',
      realm: 'way-of',
      domain: 'runestone',
      status: 'degraded',
      capabilities: ['fastify', 'zod', 'sqlite', 'a2a'],
      skills: ['tyr-check'],
      interface: { protocol: 'A2A 1.0', endpoint: 'utgard://eindri-02', signed: true },
      model: 'hermes-3-8b',
      uptime: 18 * min,
      tasksDone: 5,
      traceability: 0.964,
    },
    {
      id: 'eindri-03',
      name: 'Eindri-03',
      role: 'Smith — memory',
      realm: 'way-of',
      domain: 'muninn',
      status: 'nominal',
      capabilities: ['engram', 'embeddings', 'rag', 'fts5'],
      skills: ['workspace_rag'],
      interface: { protocol: 'A2A 1.0', endpoint: 'utgard://eindri-03', signed: true },
      model: 'hermes-3-8b',
      uptime: 9 * min,
      tasksDone: 3,
      traceability: 0.978,
    },
    {
      id: 'eindri-04',
      name: 'Eindri-04',
      role: 'Smith — isolation',
      realm: 'way-of',
      domain: 'utgard',
      status: 'down',
      capabilities: ['docker', 'cgroups', 'yggdrasil', 'seccomp'],
      skills: ['a2a-bridge'],
      interface: { protocol: 'A2A 1.0', endpoint: 'utgard://eindri-04', signed: false },
      model: 'hermes-3-8b',
      uptime: 0,
      tasksDone: 11,
      traceability: 0.941,
    },
  ];

  // Re-scope the platform crew to the active realm, and swap the primary house.
  return base.map((a) =>
    a.id === 'brokk' || a.id === 'kaia'
      ? { ...a, realm, domain: realm === 'zerwiz' ? 'muninn' : realm === 'craig' ? 'brokkforge' : a.domain }
      : { ...a, realm },
  );
}

export function seedTasks(realm: RealmId): Task[] {
  const t: Task[] = [
    {
      id: 'tsk-7f1a',
      title: 'Port the reference shell — rail, topbar, stream',
      state: 'WORKING',
      realm,
      agent: 'Eindri-01',
      agentId: 'eindri-01',
      order: 'W0026',
      progress: 62,
      startedAt: iso(34 * min),
      updatedAt: iso(40_000),
      artifacts: ['src/app/Shell.tsx', 'src/styles/shell.css'],
      log: [
        'claimed task from Redis queue ratatoskr:inbox:eindri-01',
        'yggdrasil worktree .yggdrasil/eindri-01 created (branch agent/eindri-01/shell)',
        'ported .shell grid 236px | 1fr · rows 56px · 1fr · 192px',
        'wired data-realm tint binding',
      ],
    },
    {
      id: 'tsk-3c9d',
      title: 'Heimdall GitHub OAuth — code flow + JWT session',
      state: 'INPUT_REQUIRED',
      realm,
      agent: 'Eindri-02',
      agentId: 'eindri-02',
      order: 'W0028',
      progress: 41,
      startedAt: iso(2 * 60 * min),
      updatedAt: iso(6 * min),
      artifacts: ['services/heimdall/oauth.ts'],
      log: [
        'GitHub App client id resolved from .env.local',
        'awaiting: callback URL from the captain',
        'well recall: 3 prior auth episodes found (hybrid, 0.81)',
      ],
    },
    {
      id: 'tsk-91b0',
      title: 'Workspace provisioner — idempotent first-login bootstrap',
      state: 'SUBMITTED',
      realm,
      agent: 'Kaia',
      agentId: 'kaia',
      order: 'W0029',
      progress: 0,
      startedAt: iso(3 * min),
      updatedAt: iso(3 * min),
      artifacts: [],
      log: ['submitted by Kaia', 'veil verdict: grounded (0.88) — dispatch approved'],
    },
    {
      id: 'tsk-2ae4',
      title: 'engram recall loop — hybrid + cosine modes',
      state: 'COMPLETED',
      realm,
      agent: 'Eindri-03',
      agentId: 'eindri-03',
      order: 'W0004',
      progress: 100,
      startedAt: iso(3 * 60 * min),
      updatedAt: iso(48 * min),
      artifacts: ['skills/workspace_rag.ts', 'memory/engram.jsonl'],
      log: ['observe + recall wired to 127.0.0.1:4602', 'drinking before dispatch — dry well fires cold'],
    },
    {
      id: 'tsk-6d12',
      title: 'Utgard sandbox — network-none enforcement',
      state: 'FAILED',
      realm,
      agent: 'Eindri-04',
      agentId: 'eindri-04',
      order: 'W0002',
      progress: 73,
      startedAt: iso(5 * 60 * min),
      updatedAt: iso(22 * min),
      artifacts: [],
      log: [
        'docker run --network none --cap-drop ALL',
        'FAILED: cgroup v2 write denied (no root)',
        'no trace on main — sandbox destroyed',
      ],
    },
    {
      id: 'tsk-88f5',
      title: 'Runes ledger — append-strict JSONL carver',
      state: 'WORKING',
      realm,
      agent: 'Kaia',
      agentId: 'kaia',
      order: 'W0005',
      progress: 88,
      startedAt: iso(70 * min),
      updatedAt: iso(90_000),
      artifacts: ['memory/runes_audit.md'],
      log: ['checksum chain verified', 'a rune stays carved'],
    },
    {
      id: 'tsk-04ce',
      title: 'Skrymir Vue sub-app mount in Files gate',
      state: 'SUBMITTED',
      realm,
      agent: 'Eindri-01',
      agentId: 'eindri-01',
      order: 'W0032',
      progress: 0,
      startedAt: iso(12 * min),
      updatedAt: iso(12 * min),
      artifacts: [],
      log: ['queued behind tsk-7f1a'],
    },
    {
      id: 'tsk-b731',
      title: 'A2A Agent Card JWS signing via Heimdall',
      state: 'WORKING',
      realm,
      agent: 'Eindri-02',
      agentId: 'eindri-02',
      order: 'W0008',
      progress: 35,
      startedAt: iso(26 * min),
      updatedAt: iso(2 * min),
      artifacts: [],
      log: ['/.well-known/agent-card.json published', 'signing key rotated', 'tampered cards rejected'],
    },
  ];
  return t.map((x) => ({ ...x, realm }));
}

export function seedRunes(realm: RealmId): RuneEntry[] {
  const rows: Omit<RuneEntry, 'realm'>[] = [
    { id: 'run-001', ts: iso(20_000), agent: 'Eindri-01', module: 'hlidskjalf', event: 'shell.grid.ported', checksum: 'a91f3c', order: 'W0026', level: 'ok' },
    { id: 'run-002', ts: iso(45_000), agent: 'Kaia', module: 'mimirsbrunn', event: 'recall.hybrid 3 hits', checksum: '7c0d22', order: 'W0004', level: 'info' },
    { id: 'run-003', ts: iso(70_000), agent: 'Eindri-02', module: 'ratatoskr', event: 'card.published eindri-02', checksum: 'b4e881', order: 'W0008', level: 'ok' },
    { id: 'run-004', ts: iso(120_000), agent: 'Eindri-04', module: 'utgard', event: 'cgroup.denied', checksum: 'ff19aa', order: 'W0002', level: 'danger' },
    { id: 'run-005', ts: iso(160_000), agent: 'Brokk', module: 'yggdrasil', event: 'worktree.merge agent/eindri-03', checksum: '2019d7', order: 'W0001', level: 'ok' },
    { id: 'run-006', ts: iso(200_000), agent: 'Kaia', module: 'runes', event: 'ledger.append strict', checksum: '6ea4b0', order: 'W0005', level: 'info' },
    { id: 'run-007', ts: iso(260_000), agent: 'Eindri-02', module: 'heimdall', event: 'jwt.session issued', checksum: '93bf55', order: 'W0028', level: 'info' },
    { id: 'run-008', ts: iso(320_000), agent: 'Brokk', module: 'valhalla', event: 'pm2 reload ymir-gate', checksum: 'd07c13', order: 'W0019', level: 'warn' },
    { id: 'run-009', ts: iso(400_000), agent: 'Eindri-03', module: 'mimirsbrunn', event: 'observe episode 128', checksum: '1ab9ef', order: 'W0004', level: 'ok' },
    { id: 'run-010', ts: iso(520_000), agent: 'Kaia', module: 'veil', event: 'verdict grounded 0.88', checksum: '5dd201', order: 'W0006', level: 'ok' },
    { id: 'run-011', ts: iso(640_000), agent: 'Eindri-01', module: 'gungnir', event: 'skill forged tyr-check', checksum: 'e3c790', order: 'W0007', level: 'ok' },
    { id: 'run-012', ts: iso(760_000), agent: 'Brokk', module: 'bifrost', event: 'route /files → skrymir', checksum: '88aa12', order: 'W0017', level: 'info' },
  ];
  return rows.map((r) => ({ ...r, realm }));
}

export function seedStream(realm: RealmId): StreamEvent[] {
  const s: Omit<StreamEvent, 'realm' | 'id'>[] = [
    { ts: iso(8_000), kind: 'ratatoskr', from: 'Eindri-01', to: 'Kaia', taskId: 'tsk-7f1a', state: 'WORKING', message: 'shell grid ported — 236px rail, 56px topbar', checksum: 'a91f3c' },
    { ts: iso(12_000), kind: 'rune', from: 'Eindri-01', module: 'hlidskjalf', message: 'shell.grid.ported', checksum: 'a91f3c' },
    { ts: iso(30_000), kind: 'ratatoskr', from: 'Eindri-02', to: 'Brokk', taskId: 'tsk-b731', state: 'WORKING', message: 'agent-card.json published, JWS signed', checksum: 'b4e881' },
    { ts: iso(55_000), kind: 'ratatoskr', from: 'Kaia', to: 'Eindri-03', taskId: 'tsk-2ae4', state: 'COMPLETED', message: 'recall loop complete — 3 episodes', checksum: '7c0d22' },
    { ts: iso(90_000), kind: 'rune', from: 'Eindri-04', module: 'utgard', message: 'cgroup.denied', checksum: 'ff19aa' },
    { ts: iso(140_000), kind: 'ratatoskr', from: 'Kaia', to: 'Brokk', taskId: 'tsk-91b0', state: 'SUBMITTED', message: 'dispatch approved — veil 0.88', checksum: '1c9f44' },
    { ts: iso(210_000), kind: 'rune', from: 'Brokk', module: 'valhalla', message: 'pm2 reload ymir-gate', checksum: 'd07c13' },
    { ts: iso(300_000), kind: 'ratatoskr', from: 'Eindri-04', to: 'Kaia', taskId: 'tsk-6d12', state: 'FAILED', message: 'cgroup write denied — sandbox destroyed', checksum: 'ff19aa' },
  ];
  return s.map((x, i) => ({ ...x, id: `evt-${i}`, realm }));
}

export function seedProcesses(realm: RealmId): ProcessInfo[] {
  const p: ProcessInfo[] = [
    { id: 'p1', name: 'ymir-gate', daemon: 'Fastify · API', manager: 'pm2', status: 'nominal', cpu: 3.4, mem: 182, restarts: 0, uptime: 41 * 60, realm: 'platform' },
    { id: 'p2', name: 'heimdall', daemon: 'OAuth · JWS', manager: 'pm2', status: 'nominal', cpu: 1.1, mem: 96, restarts: 0, uptime: 41 * 60, realm: 'platform' },
    { id: 'p3', name: 'mimirsbrunn', daemon: 'engram bridge :4602', manager: 'pm2', status: 'nominal', cpu: 2.2, mem: 240, restarts: 1, uptime: 39 * 60, realm: 'platform' },
    { id: 'p4', name: 'ratatoskr', daemon: 'Redis queue', manager: 'docker', status: 'nominal', cpu: 0.6, mem: 42, restarts: 0, uptime: 41 * 60, realm: 'platform' },
    { id: 'p5', name: 'hermes-runtime', daemon: 'worker controller', manager: 'pm2', status: 'degraded', cpu: 12.8, mem: 512, restarts: 3, uptime: 18 * 60, realm },
    { id: 'p6', name: 'utgard-04', daemon: 'ephemeral sandbox', manager: 'docker', status: 'down', cpu: 0, mem: 0, restarts: 5, uptime: 0, realm },
    { id: 'p7', name: 'bifrost', daemon: 'Traefik ingress', manager: 'docker', status: 'nominal', cpu: 0.9, mem: 64, restarts: 0, uptime: 41 * 60, realm: 'platform' },
    { id: 'p8', name: 'gjallarhorn', daemon: 'cloudflared tunnel', manager: 'systemd', status: 'nominal', cpu: 0.3, mem: 28, restarts: 0, uptime: 41 * 60, realm: 'platform' },
  ];
  return p.map((x) => ({ ...x, realm: x.realm === 'platform' ? 'platform' : realm }));
}

export function seedReviews(realm: RealmId): PullRequest[] {
  const r: PullRequest[] = [
    {
      id: 'pr-42', number: 42, title: 'feat(hlidskjalf): port reference shell + realm tints', repo: 'ymir', author: 'eindri-01',
      realm, state: 'open', additions: 1284, deletions: 96, updatedAt: iso(9 * min), issue: '#28',
      checks: [
        { name: 'lint', state: 'nominal' },
        { name: 'typecheck', state: 'nominal' },
        { name: 'unit', state: 'nominal' },
        { name: 'e2e', state: 'degraded' },
      ],
      checklist: [
        { label: 'Shell grid matches design.md §5.1', done: true },
        { label: 'data-realm tint on switch', done: true },
        { label: 'Bottom stream pausable', done: true },
        { label: 'A11y axe-core ≥ 95', done: false },
      ],
    },
    {
      id: 'pr-39', number: 39, title: 'fix(utgard): cgroup v2 write denied on rootless', repo: 'ymir', author: 'eindri-04',
      realm, state: 'changes', additions: 212, deletions: 40, updatedAt: iso(34 * min), issue: '#31',
      checks: [
        { name: 'lint', state: 'nominal' },
        { name: 'typecheck', state: 'nominal' },
        { name: 'integration', state: 'down' },
      ],
      checklist: [
        { label: 'Reproduce cgroup denial', done: true },
        { label: 'delegate cgroup to rootless driver', done: false },
        { label: 'No trace on main on failure', done: true },
      ],
    },
    {
      id: 'pr-37', number: 37, title: 'feat(mimirsbrunn): hybrid recall + observe loop', repo: 'ymir', author: 'eindri-03',
      realm, state: 'approved', additions: 640, deletions: 12, updatedAt: iso(48 * min),
      checks: [
        { name: 'lint', state: 'nominal' },
        { name: 'typecheck', state: 'nominal' },
        { name: 'unit', state: 'nominal' },
      ],
      checklist: [
        { label: 'Dry well fires cold', done: true },
        { label: 'agent-scoped keys', done: true },
      ],
    },
  ];
  return r.map((x) => ({ ...x, realm }));
}

export function seedRecall(realm: RealmId): RecallEpisode[] {
  const e: RecallEpisode[] = [
    { id: 'ep-1', title: 'Reference shell is the visual contract', body: 'The plan forbids re-drawing the CSS. tokens.css is the single source; port the shell verbatim and bind data-realm at runtime.', score: 0.91, mode: 'hybrid', agentScope: 'agent://way-of/brokk', ts: iso(2 * 60 * min), tags: ['hlidskjalf', 'design-system'] },
    { id: 'ep-2', title: 'Memory is a boost, never a blocker', body: 'A dry well fires cold but must never stop the forge. Recall before dispatch, observe after; never gate work on the well.', score: 0.87, mode: 'hybrid', agentScope: 'agent://way-of/kaia', ts: iso(6 * 60 * min), tags: ['mimirsbrunn', 'doctrine'] },
    { id: 'ep-3', title: 'Terminal A2A states never restart', body: 'COMPLETED/FAILED/REJECTED/CANCELED are terminal. Retry and idempotency are the orchestrator\'s duty, not the worker\'s.', score: 0.78, mode: 'cosine', agentScope: 'agent://way-of/kaia', ts: iso(24 * 60 * min), tags: ['ratatoskr', 'a2a'] },
    { id: 'ep-4', title: 'Failed sandbox never touches main', body: 'Utgard runs network-none with strict caps. On failure the container is destroyed and the worktree is discarded.', score: 0.71, mode: 'spreading', agentScope: 'agent://way-of/eindri-04', ts: iso(5 * 60 * min), tags: ['utgard', 'isolation'] },
  ];
  void realm;
  return e;
}

export function seedFiles(realm: RealmId): FileNode {
  return {
    name: realm,
    type: 'dir',
    path: `/svartalfaheim/${realm}`,
    children: [
      {
        name: 'workspace', type: 'dir', path: `/svartalfaheim/${realm}/workspace`, children: [
          { name: 'company', type: 'dir', path: `/svartalfaheim/${realm}/workspace/company`, children: [
            { name: 'offer.md', type: 'file', path: '/company/offer.md', size: 4210, updated: iso(2 * 60 * min) },
            { name: 'brand.md', type: 'file', path: '/company/brand.md', size: 2880, updated: iso(9 * 60 * min) },
          ] },
          { name: 'development', type: 'dir', path: `/svartalfaheim/${realm}/workspace/development`, children: [
            { name: 'specs', type: 'dir', path: '/development/specs', children: [
              { name: 'hlidskjalf.md', type: 'file', path: '/development/specs/hlidskjalf.md', size: 15420, updated: iso(40_000) },
            ] },
          ] },
          { name: 'memory', type: 'dir', path: `/svartalfaheim/${realm}/workspace/memory`, children: [
            { name: 'daily', type: 'dir', path: '/memory/daily', children: [
              { name: '2026-09-11.md', type: 'file', path: '/memory/daily/2026-09-11.md', size: 3120, updated: iso(3 * 60 * min) },
            ] },
            { name: 'entity_graph', type: 'dir', path: '/memory/entity_graph', children: [] },
          ] },
          { name: 'life', type: 'dir', path: `/svartalfaheim/${realm}/workspace/life`, children: [] },
          { name: 'marketing', type: 'dir', path: `/svartalfaheim/${realm}/workspace/marketing`, children: [] },
        ],
      },
      { name: '.env.realm', type: 'file', path: '/.env.realm', size: 0, updated: iso(60 * 60 * min) },
      { name: 'Brokk.md', type: 'file', path: '/Brokk.md', size: 5120, updated: iso(60 * 60 * min) },
      { name: 'projects', type: 'dir', path: `/svartalfaheim/${realm}/projects`, children: [] },
    ],
  };
}

export function seedSkills(): SkillDef[] {
  return [
    { id: 'skl-galdr', name: 'galdr', aett: 'galdr', description: 'Agent experience incantation standards — TOON output, 10 principles.', capabilities: ['cli', 'toon', 'ergonomics'], validated: true, domain: 'ymirlabs', createdAt: iso(48 * 60 * min) },
    { id: 'skl-tyr', name: 'tyr-check', aett: 'galdr', description: 'The judge — validates tools, skills, and docs against Galdr.', capabilities: ['validation', 'compliance'], validated: true, domain: 'runestone', createdAt: iso(40 * 60 * min) },
    { id: 'skl-brokk', name: 'brokk-craft', aett: 'galdr', description: 'The forger — generates Galdr-compliant skills in TOON.', capabilities: ['synthesis', 'skills'], validated: true, domain: 'brokkforge', createdAt: iso(36 * 60 * min) },
    { id: 'skl-a2a', name: 'a2a-bridge', aett: 'rat', description: 'Canonical collaboration skill — inbox per turn, complete tasks, FYI peers.', capabilities: ['a2a', 'collaboration'], validated: true, domain: 'ymirlabs', createdAt: iso(30 * 60 * min) },
    { id: 'skl-rag', name: 'workspace_rag', aett: 'mimir', description: 'Hybrid Markdown + vector recall across the workspace.', capabilities: ['rag', 'memory'], validated: false, domain: 'muninn', createdAt: iso(20 * 60 * min) },
  ];
}

export function seedChat(): ChatMessage[] {
  return [
    { id: 'm1', from: 'kaia', body: 'Well is warm. 128 episodes observed. What are we forging?', ts: iso(4 * 60 * min) },
    { id: 'm2', from: 'user', body: 'Build out the Hlidskjalf frontend so I can see it on localhost.', ts: iso(3 * 60 * min) },
    { id: 'm3', from: 'kaia', body: 'Recalled 4 episodes (hybrid, top 0.91). Dispatching Eindri-01 on the shell port under W0026. Veil verdict: grounded.', ts: iso(3 * 60 * min), recalling: true },
  ];
}

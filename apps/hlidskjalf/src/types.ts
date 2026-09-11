// Known realms autocomplete; arbitrary realm ids are allowed so a freshly
// provisioned tenant (first GitHub login) can exist without a rebuild.
export type RealmId = 'way-of' | 'zerwiz' | 'craig' | (string & {});

export type TenantRole = 'owner' | 'admin' | 'member';

export interface TenantGrant {
  realm: RealmId;
  tenant: string;
  role: TenantRole;
  house: HouseId;
  tint: string;
  glyph: string;
}

export interface User {
  login: string;
  name: string;
  email: string;
  avatar: string;
}

export interface Session {
  user: User;
  tenants: TenantGrant[];
  method: 'github';
  issuedAt: string;
  /** mock JWS — replaced by Heimdall-issued httpOnly JWT once W0028 lands */
  token: string;
}

export type HouseId =
  | 'ymirlabs'
  | 'brokkforge'
  | 'runestone'
  | 'muninn'
  | 'dvalin'
  | 'utgard'
  | 'askr'
  | 'mannheim';

export type AgentStatus = 'nominal' | 'degraded' | 'down';

export type TaskState =
  | 'SUBMITTED'
  | 'WORKING'
  | 'COMPLETED'
  | 'FAILED'
  | 'REJECTED'
  | 'CANCELED'
  | 'INPUT_REQUIRED'
  | 'AUTH_REQUIRED';

export type GateId =
  | 'fleet'
  | 'tasks'
  | 'well'
  | 'runes'
  | 'reviews'
  | 'processes'
  | 'files'
  | 'chat'
  | 'forge'
  | 'profile'
  | 'runtime'
  | 'cron'
  | 'sessions'
  | 'trace'
  | 'decisions'
  | 'stats';

export interface SkillDef {
  id: string;
  name: string;
  /** Norse aett prefix (galdr-, mimir-, yggd-, rat-, heimd-, bifr-, val-, skyr-) */
  aett: string;
  description: string;
  capabilities: string[];
  validated: boolean;
  house: HouseId;
  createdAt: string;
}

export interface AgentCard {
  id: string;
  name: string;
  role: string;
  realm: RealmId;
  house: HouseId;
  status: AgentStatus;
  capabilities: string[];
  skills: string[];
  interface: {
    protocol: string;
    endpoint: string;
    signed: boolean;
  };
  model: string;
  uptime: number;
  tasksDone: number;
  traceability: number;
}

export interface Task {
  id: string;
  title: string;
  state: TaskState;
  realm: RealmId;
  agent: string;
  agentId: string;
  order: string;
  progress: number;
  startedAt: string;
  updatedAt: string;
  artifacts: string[];
  log: string[];
}

export interface RuneEntry {
  id: string;
  ts: string;
  agent: string;
  module: string;
  event: string;
  checksum: string;
  realm: RealmId;
  order: string;
  level: 'info' | 'ok' | 'warn' | 'danger';
}

export interface StreamEvent {
  id: string;
  ts: string;
  kind: 'ratatoskr' | 'rune';
  from: string;
  to?: string;
  taskId?: string;
  state?: TaskState;
  module?: string;
  message: string;
  checksum?: string;
}

export interface RecallEpisode {
  id: string;
  title: string;
  body: string;
  score: number;
  mode: 'hybrid' | 'cosine' | 'spreading';
  agentScope: string;
  ts: string;
  tags: string[];
}

export interface ProcessInfo {
  id: string;
  name: string;
  daemon: string;
  manager: 'pm2' | 'docker' | 'systemd';
  status: AgentStatus;
  cpu: number;
  mem: number;
  restarts: number;
  uptime: number;
  realm: RealmId | 'platform';
}

export interface PullRequest {
  id: string;
  number: number;
  title: string;
  repo: string;
  author: string;
  realm: RealmId;
  state: 'open' | 'draft' | 'changes' | 'approved' | 'merged';
  checks: { name: string; state: AgentStatus }[];
  checklist: { label: string; done: boolean }[];
  additions: number;
  deletions: number;
  issue?: string;
  updatedAt: string;
}

export interface FileNode {
  name: string;
  type: 'dir' | 'file';
  path: string;
  size?: number;
  updated?: string;
  children?: FileNode[];
}

export interface ChatMessage {
  id: string;
  from: 'user' | 'kaia';
  body: string;
  ts: string;
  recalling?: boolean;
}

export interface RealmDef {
  id: RealmId;
  tenant: string;
  house: HouseId;
  tint: string;
  tint2: string;
  glyph: string;
}

export interface HouseDef {
  id: HouseId;
  name: string;
  accent: string;
  glyph: string;
}

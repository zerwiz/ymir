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
  Task,
} from '../types';

/**
 * Gate API client (W0027 surface).
 *
 * Points at the local Hlidskjalf gate server (`apps/hlidskjalf/server`, default
 * :3889). In dev, Vite proxies `/api` to it, so an empty BASE works. Set
 * `VITE_API_URL` to override. Every call carries the session cookie; a 401
 * re-locks the gate.
 */
const BASE = (import.meta.env.VITE_API_URL as string | undefined) ?? '';

export const demoMode = import.meta.env.VITE_DEMO === '1';

export interface RuntimeInfo {
  digest: string;
  markers: { lock: string; started: boolean; armed: boolean };
  doc: string;
}

export interface CronJob {
  at: string;
  command: string;
  status: string;
}
export interface CronInfo {
  running: boolean;
  pid: string;
  jobs: CronJob[];
}

export interface LoaderRow {
  tool: string;
  path: string;
  status: string;
}
export interface CheckRow {
  id: string;
  check: string;
  status: string;
  detail: string;
}
export interface OrderRow {
  id: string;
  title: string;
  phase: string;
  status: string;
}
export interface OrdersInfo {
  open: number;
  orders: OrderRow[];
}

/**
 * The desktop seat (Electron) marks its requests, and the gate then never asks it
 * to log in: the shell is a local, trusted seat, while the web door keeps its
 * lock. The marker is only honoured by the gate when the request really arrives
 * over loopback, so a web caller cannot borrow it.
 */
export function isDesktopSeat(): boolean {
  const w = window as unknown as { ymirDesktop?: { desktop?: boolean } };
  return w.ymirDesktop?.desktop === true;
}

export function desktopHeaders(extra: Record<string, string> = {}): Record<string, string> {
  return isDesktopSeat() ? { 'x-ymir-surface': 'desktop', ...extra } : extra;
}

/** A 401 from a real endpoint re-locks the gate; the login/session calls must not. */
function noteUnauthorized(path: string, status: number): void {
  if (status === 401 && !path.startsWith('/api/login') && !path.startsWith('/api/session')) {
    window.dispatchEvent(new Event('ymir:unauthorized'));
  }
}

async function get<T>(path: string): Promise<T> {
  // Bound every call so one slow endpoint can never stall a combined load.
  const ctrl = new AbortController();
  const timer = window.setTimeout(() => ctrl.abort(), 10_000);
  try {
    const res = await fetch(`${BASE}${path}`, { credentials: 'include', headers: desktopHeaders(), signal: ctrl.signal });
    noteUnauthorized(path, res.status);
    if (!res.ok) throw new Error(`${path} → ${res.status}`);
    return (await res.json()) as T;
  } finally {
    window.clearTimeout(timer);
  }
}

async function post<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    credentials: 'include',
    headers: desktopHeaders({ 'content-type': 'application/json' }),
    body: JSON.stringify(body),
  });
  noteUnauthorized(path, res.status);
  // The gate explains refusals in its own words (a spent invite code, a taken
  // username, a short password). Carry that sentence to the caller rather than a
  // bare status, so the surface can say what is actually wrong.
  if (!res.ok) throw new Error(await errorText(res, path));
  return (await res.json()) as T;
}

/** The server's own error sentence when it sent one; a plain status when not. */
async function errorText(res: Response, path: string): Promise<string> {
  try {
    const body = (await res.clone().json()) as { error?: string };
    if (body?.error) return body.error;
  } catch {
    /* not JSON — fall through to the status */
  }
  return `${path} → ${res.status}`;
}

async function del<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`, { method: 'DELETE', credentials: 'include', headers: desktopHeaders() });
  noteUnauthorized(path, res.status);
  if (!res.ok) throw new Error(`${path} → ${res.status}`);
  return (await res.json()) as T;
}

export interface ChatReply {
  reply: ChatMessage;
  live: boolean;
}

export interface ChatSession {
  id: string;
  messages: number;
  updated_at: string | null;
}
export interface ChatModel {
  id: string;
  name: string;
  provider: string;
  kind: 'local' | 'online';
}
export interface ChatSendOptions {
  session?: string;
  model?: string;
  agents?: string[];
}
export interface PromptFile {
  agent: string;
  kind: 'system' | 'user';
  path: string;
  body: string;
}
export interface MimirHealth {
  status: string;
  store: string | null;
  episodes: number;
  agents: string[];
}
export interface WorkspaceRow {
  id: string;
  name: string;
  kind: string;
  company?: string;
  domains: string[];
}
export interface SetupStep {
  step: string;
  status: string;
  detail: string;
}
export interface WellEpisode {
  id: string;
  content: string;
  timestamp: string;
  tags: string[];
  actors: string[];
  agent_id: string | null;
}

export interface SmidjaSession {
  smidja_id: string;
  smidja_name: string | null;
  status: string | null;
  engineer: string | null;
  total_tokens: number | null;
  total_cost: number | null;
  started_at: string | null;
  ended_at: string | null;
}
export interface SmidjaPhase {
  phase_id: string;
  seq: number | null;
  name: string | null;
  kind: string | null;
  owner: string | null;
  description: string | null;
  status: string | null;
  attempt: number | null;
  error: string | null;
  started_at: string | null;
  ended_at: string | null;
}
export interface SmidjaEvent {
  rowid: number;
  type: string | null;
  name: string | null;
  phase_id: string | null;
  parent_id: string | null;
  payload_json: string | null;
  tokens: number | null;
  started_at: string | null;
  ended_at: string | null;
}
export interface SmidjaAgent {
  agent: string;
  coding_agent: string | null;
  model: string | null;
  context_tokens: number | null;
  context_window: number | null;
}
export interface SmidjaDetail {
  session: SmidjaSession;
  phases: SmidjaPhase[];
  events: SmidjaEvent[];
  envelopes: unknown[];
  gates: unknown[];
  agents: SmidjaAgent[];
}
export interface SmidjaDecision {
  phase: string;
  error: string | null;
  model: string | null;
  count: number;
}
export interface StatsTotals {
  runs: number;
  success: number;
  fail: number;
  running: number;
  tokens: number;
  cost: number;
}
export interface StatsUsage {
  input: number;
  output: number;
  cache_read: number;
  cache_write: number;
  total: number;
}
export interface VendorCost {
  cached_cost: number;
  total_cost: number;
  savings: number;
  savings_pct: number;
}
export interface VendorModelCost extends VendorCost {
  id: string;
  name: string;
  provider: string;
  tier: 1 | 2 | 3;
  rank: number;
  tier_label: string;
  input_price: number;
  output_price: number;
  cache_price: number;
}
export type ModelKind = 'local' | 'online';
export interface ProviderStat {
  events: number;
  sessions: number;
  tokens: number;
  cost: number;
  input: number;
  output: number;
  cache_read: number;
}
export interface ModelProviderStat {
  model: string;
  kind: ModelKind;
  coding_agent: string | null;
  events: number;
  tokens: number;
  cost: number;
}
export interface ProviderBreakdown {
  local: ProviderStat;
  online: ProviderStat;
  per_model: ModelProviderStat[];
}
export interface ChainStat {
  chain: string;
  runs: number;
  success: number;
  tokens: number;
  cost: number;
}
export interface ModelStat {
  model: string;
  runs: number;
  success: number;
  tokens: number;
  cost: number;
}
export interface SmidjaStats {
  totals: StatsTotals;
  usage: StatsUsage;
  cache_hit_ratio: number;
  avg_cache_hit_per_run: number;
  vendors: { gpt4o: VendorCost; gemini: VendorCost };
  vendor_catalog: VendorModelCost[];
  providers: ProviderBreakdown;
  by_chain: ChainStat[];
  by_model: ModelStat[];
  generated_at: string;
}

export const gateApi = {
  health: () => get<{ ok: boolean; root: string }>('/api/health'),
  me: () => get<{ login: string; realm: RealmId }>('/api/me'),
  workspace: () => get<{ realm: RealmId; path: string }>('/api/workspace'),
  agents: () => get<AgentCard[]>('/api/agents'),
  tasks: () => get<Task[]>('/api/tasks'),
  well: (q: string) => get<RecallEpisode[]>(`/api/well?q=${encodeURIComponent(q)}`),
  runes: () => get<RuneEntry[]>('/api/runes'),
  processes: () => get<ProcessInfo[]>('/api/processes'),
  reviews: () => get<PullRequest[]>('/api/reviews'),
  files: (realm?: string) =>
    get<FileNode>(`/api/files${realm ? `?realm=${encodeURIComponent(realm)}` : ''}`),
  file: (realm: string, path: string) =>
    get<{ path: string; size?: number; updated?: string; body?: string; note?: string; error?: string }>(
      `/api/file?realm=${encodeURIComponent(realm)}&path=${encodeURIComponent(path)}`,
    ),
  skills: () => get<SkillDef[]>('/api/skills'),
  runtime: () => get<RuntimeInfo>('/api/runtime'),
  cron: () => get<CronInfo>('/api/cron'),
  loaders: () => get<LoaderRow[]>('/api/loaders'),
  checks: () => get<CheckRow[]>('/api/checks'),
  orders: () => get<OrdersInfo>('/api/orders'),
  chatHistory: (session = 'default') => get<ChatMessage[]>(`/api/chat/history?session=${encodeURIComponent(session)}`),
  chatSessions: () => get<ChatSession[]>('/api/chat/sessions'),
  chatModels: () => get<ChatModel[]>('/api/chat/models'),
  chat: (content: string, opts: ChatSendOptions = {}) => post<ChatReply>('/api/chat', { content, ...opts }),
  deleteChatSession: (session: string) => del<{ ok: boolean }>(`/api/chat/session?session=${encodeURIComponent(session)}`),
  prompts: () => get<PromptFile[]>('/api/prompts'),
  savePrompt: (agent: string, kind: string, body: string) =>
    post<{ ok: boolean; path: string }>('/api/prompts', { agent, kind, body }),
  session: () => get<{ authed: boolean; login?: string | null; registration?: boolean; github?: boolean }>('/api/session'),
  login: (username: string, password: string) => post<{ ok: boolean }>('/api/login', { username, password }),
  /**
   * Create an account from an invite code. Registration is refused unless the
   * code is live — the gate, not this call, is what decides.
   */
  register: (username: string, password: string, invite: string) =>
    post<{ ok: boolean }>('/api/register', { username, password, invite }),
  /**
   * Raise a desktop app (Hlidskjalf or Smiðja) from inside the UI — the same
   * launcher the key bindings use, so it raises what is up and starts what is not.
   */
  desktop: (view: 'hlidskjalf' | 'smidja' | 'sessrumnir') =>
    post<{ view: string; ok: boolean; output: string }>('/api/desktop', { view }),
  logout: () => post<{ ok: boolean }>('/api/logout', {}),
  /**
   * Begin GitHub sign-in. The gate answers with an authorize URL when it is
   * configured, and with the exact reason when it is not.
   */
  githubStart: () => get<{ url?: string; error?: string }>('/api/auth/github'),
  smidjaHealth: () => get<{ db: string; sessions: number }>('/api/smidja/health'),
  smidjaSessions: () => get<SmidjaSession[]>('/api/smidja/sessions'),
  smidjaSession: (id: string) => get<SmidjaDetail>(`/api/smidja/sessions/${encodeURIComponent(id)}`),
  smidjaDecisions: () => get<{ total_failed: number; decisions: SmidjaDecision[] }>('/api/smidja/decisions'),
  smidjaStats: () => get<SmidjaStats>('/api/smidja/stats'),
  mimirHealth: () => get<MimirHealth>('/api/mimir/health'),
  workspaces: () => get<WorkspaceRow[]>('/api/workspaces'),
  createWorkspace: (body: { name: string; kind: string; domains: string[] }) =>
    post<unknown>('/api/workspaces', body),
  setupStatus: () => get<SetupStep[]>('/api/setup/status'),
  setupRun: () => post<SetupStep[]>('/api/setup/run', {}),
  wellEpisode: (id: string) => get<{ episode: WellEpisode }>(`/api/well/episode?id=${encodeURIComponent(id)}`),
};

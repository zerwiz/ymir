import type {
  AgentCard,
  ChatMessage,
  FileNode,
  ProcessInfo,
  ReviewsInfo,
  RecallEpisode,
  RealmId,
  RuneEntry,
  SkillDef,
  Task,
  A2ATraffic,
  Doors,
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

export interface DigestErrand {
  id: string;
  state: string;
  pane: string;
  detail: string;
}

export interface DigestTodo {
  area: string;
  text: string;
  id: string;
  due?: string;
  high?: boolean;
}

export interface DigestView {
  helm: {
    seat: string;
    machine: string;
    role: string;
    pin: string;
    behind: string;
    pid: string;
    heartbeat: string;
    holder: boolean;
  } | null;
  next: string;
  decisions: number;
  wakes: number;
  errands: DigestErrand[];
  unreadable: DigestErrand[];
  finished: number;
  finishedIds: string[];
  todos: DigestTodo[];
  todosOpen: number;
  sections: string[];
  parsed: boolean;
}

export interface ReleaseService {
  unit: string;
  state: string;
  pid: number;
  release: string;
  onPin: boolean;
  running: boolean;
  started: string;
  why: string;
}

/** What `/api/runtime` answers: the digest as a person reads it (item 25), the
 *  release each service runs from (item 27), and the raw text for the fold. */
export interface RuntimeInfo {
  digest: string;
  /** null while the digest is being read for the first time (it takes ~12 s). */
  view: DigestView | null;
  reading: boolean;
  services: { pin: string; services: ReleaseService[]; error?: string };
  mail: { needs: number; unsure: number; accounts: string[]; error?: string };
  markers: { lock: string; started: boolean; armed: boolean };
  doc: string;
}

/* ---- the soak ledger and the Health view (plan 286 P6) ------------------- *
 * `holds` / `grows` / `restarts` are the only verdicts a row carries, and
 * `unknown` is the honest fourth answer when there is not enough to judge. The
 * budgets are plan 286 §5, read from the gate so the page never invents them. */
export type SoakVerdict = 'holds' | 'grows' | 'restarts' | 'unknown';

export interface SoakBudgets {
  idleMinutes: number;
  rssPctIdle: number;
  rssPctCycles: number;
  heapMbIdle: number;
  heapMbCycles: number;
  longTaskMsIdle: number;
  longTaskMsCycles: number;
  restartsPerHour: number;
  sampleIntervalMinutes: number;
}

export interface ServiceTrend {
  name: string;
  state: string;
  sub: string;
  samples: number;
  windowMinutes: number;
  firstTs: string;
  lastTs: string;
  rssStartMb: number | null;
  rssNowMb: number | null;
  rssPeakMb: number | null;
  rssPct: number | null;
  fdsStart: number | null;
  fdsNow: number | null;
  fdsDelta: number | null;
  watchesStart: number | null;
  watchesNow: number | null;
  watchesDelta: number | null;
  childrenStart: number | null;
  childrenNow: number | null;
  childrenDelta: number | null;
  zombies: number;
  gpuMib: number | null;
  restarts: number;
  restartsInWindow: number;
  verdict: SoakVerdict;
  why: string;
}

export interface AppHealth {
  app: string;
  present: boolean;
  date: string;
  samples: number;
  windowMinutes: number;
  rssPct: number | null;
  rssStartMb: number | null;
  rssNowMb: number | null;
  heapMbDelta: number | null;
  fdsDelta: number | null;
  watchesDelta: number | null;
  childrenDelta: number | null;
  gpuMib: number | null;
  maxLongTaskMs: number | null;
  notResponding: number;
  cycles: number;
  applied: 'idle' | 'cycles';
  verdict: SoakVerdict;
  why: string;
  sampled?: { rssMb: number | null; fds: number | null; watches: number | null; children: number | null; gpuMib: number | null; state: string } | null;
}

export interface SoakHealth {
  state: string;
  budget: SoakBudgets;
  windowMinutes: number;
  lastPass: string;
  ageMinutes: number | null;
  passes: number;
  stale: boolean;
  services: ServiceTrend[];
  apps: AppHealth[];
  storms: Array<{ name: string; ts: string; action: string; restarts: number; threshold: number; lastError: string }>;
  error?: string;
}

/* ---- the live tail (Snotra) ----------------------------------------------- *
 * The gate is a FRONT for systems/snotra/services/ear/snotra-live.sh; these shapes are
 * what that script says, never a second opinion. `closing` is the gate's own
 * word for a stop it spawned and has not finished draining (stop takes minutes:
 * it re-transcribes the recording and asks the rail for the summary). */
export interface LiveTailStatus {
  state: 'idle' | 'listening' | 'closing';
  pid?: string;
  slices?: number;
  doc?: string;
  /** Newest-last, as the document grows: `[hh:mm:ss] text`. */
  lines?: string[];
  /** The script's own sentence after the row. */
  said?: string;
}

export interface LiveTailStartResponse {
  ok: boolean;
  slug?: string;
  said?: string;
  /** The SCRIPT's refusal sentence, verbatim ("ONE ear at a time" and friends). */
  error?: string;
}

export interface LiveTailStopResponse {
  closing: boolean;
  error?: string;
}

/* ---- the mail desk (Gná, plan 116) ---------------------------------------- *
 * The gate is a FRONT for hodd/bin/gna-agent/gna_desk.py on 127.0.0.1:8490.
 * Those shapes are that service's own answer, never a second opinion: a column
 * count, the row's evidence, and the account it belongs to. There is no send
 * capability behind any of these, and no method here can acquire one. */
export type MailColumn = 'needs_you' | 'unsure' | 'waiting' | 'done';

export interface MailRow {
  id: string;
  account: string;
  from: { name: string; email: string };
  subject: string | null;
  received_at: string;
  summary: string;
  classification: string;
  confidence: number;
  proposed_action: string;
  person_id: string | null;
  project_id: string | null;
  matched_by: string;
  evidence: string;
  column: MailColumn;
}

export interface MailMessage extends MailRow {
  body_text: string;
}

export interface MailQueue {
  account: string;
  window_hours: number;
  columns: Record<MailColumn, MailRow[]>;
  counts: Record<MailColumn, number>;
  /** ISO instant of the oldest message still waiting on a human, or "". */
  oldest_waiting: string;
}

export interface CronJob {
  at: string;
  command: string;
  role?: string;
  status: string;
  applies?: boolean;
}
export interface CronInfo {
  running: boolean;
  pid: string;
  why?: string;
  source?: 'home' | 'repo' | 'example' | 'none';
  roles?: string[];
  jobs: CronJob[];
  last?: Record<string, string>;
}
export interface CronSeat {
  seat: string;
  host: string;
  reachable: boolean;
  running: boolean;
  pid: string;
  roles: string[];
  jobs: number;
  applies: number;
  error?: string;
}

/** One event from Mánagandr's cache, normalised by the gate (plan 60). */
export interface CalendarEvent {
  id: string;
  title: string;
  /** ISO start. */
  start: string;
  /** ISO end, or null for an all-day event. */
  end: string | null;
  allDay: boolean;
  cancelled: boolean;
  calendarId: string;
  /** Present only when the reader carried it — a count, never names. */
  attendees?: number;
}
export interface CalendarInfo {
  as_of: string | null;
  /** ok = fresh & readable · unknown = exists, freshness unprovable · absent = no cache. */
  state: 'ok' | 'unknown' | 'absent';
  events: CalendarEvent[];
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
export interface UsageModelRow {
  source: string;
  harness?: string;
  agent?: string;
  provider?: string;
  model: string;
  /** local = this machine's own rail; online = a cloud API. Decided by where it RAN. */
  kind?: 'local' | 'online';
  messages: number;
  sessions: number;
  input: number;
  output: number;
  cache_read: number;
  cache_write?: number;
  reasoning?: number;
  /** null = this call is NOT priced (unknown), never 0 for an unpriced online model. */
  cost?: number | null;
  cost_source?: 'recorded' | 'list' | 'local' | 'none' | 'unknown';
}

/** One harness's presence in the window — read, or skipped with its reason. */
export interface UsageSource {
  ok?: boolean;
  model?: string;
  skip?: string;
  error?: string;
  homes?: string[];
  messages?: number;
  sessions?: number;
  input?: number;
  output?: number;
  cache_read?: number;
  cache_write?: number;
}

/** What EVERY harness spent (opencode · pi · Claude Code · Codex · Hermes) — plan 275 item 29. */
export interface YmirUsage {
  window_days: number;
  sources: Record<string, UsageSource>;
  totals: {
    messages: number;
    sessions: number;
    input: number;
    output: number;
    cache_read: number;
    cache_write: number;
    reasoning?: number;
    total: number;
    /** input + cache_read — the tokens actually sent to a model. */
    prompt?: number;
    cache_hit_ratio: number;
    /** null when nothing in the window is priced. */
    cost?: number | null;
    cost_unknown_calls?: number;
  };
  by_model: UsageModelRow[];
  /** A RUN is a session; success/fail are null where no harness records them. */
  runs?: {
    total: number;
    messages: number;
    success: number | null;
    fail: number | null;
    unknown?: number;
    success_rate: number | null;
    tokens: number;
    cost: number | null;
    cost_unknown_calls?: number;
    by_source: Record<string, number>;
  };
  local_online?: Record<'local' | 'online', {
    tokens: number; calls: number; sessions: number; input: number; output: number;
    cache_read: number; cost: number | null;
  }>;
  /** The same numbers under the names the Statistics gate renders. */
  gate?: {
    totals: {
      runs: number; messages?: number; success: number | null; fail: number | null;
      running: number; tokens: number; cost: number | null; cost_unknown_calls?: number;
    };
    usage: {
      input: number; output: number; cache_read: number; cache_write: number;
      total: number; prompt?: number; cache_hit_ratio?: number;
    };
    providers: { local: any; online: any; per_model: any[] };
    by_chain: any[];
    by_harness?: any[];
    by_model: any[];
  };
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

/**
 * A 401 from a real endpoint is reported, never a silent empty board (plan 275
 * item 30: the halls carry no login, so the only 401 left is the local ward —
 * a voice or Rödd door refusing a request that did not arrive on loopback).
 */
function noteUnauthorized(_path: string, status: number): void {
  if (status === 401) window.dispatchEvent(new Event('ymir:unauthorized'));
}

/**
 * A gate failure that keeps its HTTP status, so a surface can say WHICH failure
 * it was: an unauthorised gate is not an empty roster, and an unreachable gate is
 * not an empty roster either. A bare Error hid that distinction (2026-09-27).
 */
export class GateError extends Error {
  readonly status: number;
  constructor(status: number, message: string) {
    super(message);
    this.name = 'GateError';
    this.status = status;
  }
}

async function get<T>(path: string): Promise<T> {
  // Bound every call so one slow endpoint can never stall a combined load.
  const ctrl = new AbortController();
  const timer = window.setTimeout(() => ctrl.abort(), 10_000);
  try {
    const res = await fetch(`${BASE}${path}`, { credentials: 'include', headers: desktopHeaders(), signal: ctrl.signal });
    noteUnauthorized(path, res.status);
    if (!res.ok) throw new GateError(res.status, `${path} → ${res.status}`);
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
  if (!res.ok) throw new GateError(res.status, await errorText(res, path));
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
  if (!res.ok) throw new GateError(res.status, `${path} → ${res.status}`);
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
  /** Days a fact was superseded — timestamps only, the well lane's decay axis. */
  superseded_dates?: string[];
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
  /** input + cache_read: the tokens actually sent to a model (plan 275 item 29). */
  prompt?: number;
  /** cache_read / prompt — the share of every prompt that came from cache. */
  cache_hit_ratio?: number;
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
  ward: () => get<{
    paused: boolean; heartbeat: string; heartbeatAgeSeconds: number; silent: boolean;
    findings: number; judged: number; bySeverity: Record<string, number>;
    newest: Array<{ ts: string; severity: string; line: string; title: string; comm: string; pid: string; reasoning?: { rung: string; model: string } | null }>;
    door: string;
  }>('/api/ward'),
  me: () => get<{ login: string; realm: RealmId }>('/api/me'),
  workspace: () => get<{ realm: RealmId; path: string }>('/api/workspace'),
  agents: () => get<AgentCard[]>('/api/agents'),
  tasks: () => get<Task[]>('/api/tasks'),
  /** The herdr traffic between agents, newest first — read from the fleet message log. */
  a2aMessages: (n = 40) => get<A2ATraffic>(`/api/a2a/messages?n=${n}`),
  /** Every app's DevTools port and every agent's pane — the inspection doors. */
  doors: () => get<Doors>('/api/doors'),
  well: (q: string) => get<RecallEpisode[]>(`/api/well?q=${encodeURIComponent(q)}`),
  runes: () => get<RuneEntry[]>('/api/runes'),
  processes: () => get<ProcessInfo[]>('/api/processes'),
  reviews: () => get<ReviewsInfo>('/api/reviews'),
  files: (path?: string) =>
    // ONE folder at a time (plan 275 item 21): the whole home is Skrymir's root and
    // a folder is read when it is opened, so a tree never walks the home to paint.
    get<FileNode>(`/api/files${path ? `?path=${encodeURIComponent(path)}` : ''}`),
  file: (path: string) =>
    get<{ path: string; size?: number; updated?: string; body?: string; note?: string; error?: string }>(
      `/api/file?path=${encodeURIComponent(path)}`,
    ),
  skills: () => get<SkillDef[]>('/api/skills'),
  runtime: () => get<RuntimeInfo>('/api/runtime'),
  soak: () => get<SoakHealth>('/api/soak'),
  calendar: () => get<CalendarInfo>('/api/calendar'),
  cron: () => get<CronInfo>('/api/cron'),
  cronStart: () => post<CronInfo & { ok: boolean; action: string; said: string }>('/api/cron/start', {}),
  cronStop: () => post<CronInfo & { ok: boolean; action: string; said: string }>('/api/cron/stop', {}),
  cronSeats: () => get<CronSeat[]>('/api/cron/seats'),
  loaders: () => get<LoaderRow[]>('/api/loaders'),
  checks: () => get<CheckRow[]>('/api/checks'),
  orders: () => get<OrdersInfo>('/api/orders'),
    usage: () => get<YmirUsage>('/api/usage'),
  chatHistory: (session = 'default') => get<ChatMessage[]>(`/api/chat/history?session=${encodeURIComponent(session)}`),
  chatSessions: () => get<ChatSession[]>('/api/chat/sessions'),
  chatModels: () => get<ChatModel[]>('/api/chat/models'),
  chat: (content: string, opts: ChatSendOptions = {}) => post<ChatReply>('/api/chat', { content, ...opts }),
  deleteChatSession: (session: string) => del<{ ok: boolean }>(`/api/chat/session?session=${encodeURIComponent(session)}`),
  prompts: () => get<PromptFile[]>('/api/prompts'),
  savePrompt: (agent: string, kind: string, body: string) =>
    post<{ ok: boolean; path: string }>('/api/prompts', { agent, kind, body }),
  /**
   * Who this seat is. NOT a credential (plan 275 item 30): the halls are local and
   * the desktop session is the authority, so the gate answers with the operator's
   * own name and nothing to sign in with.
   */
  session: () => get<{ login: string; surface: string; doc?: string }>('/api/session'),
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
  liveStatus: () => get<LiveTailStatus>('/api/snotra/live'),
  liveStart: (slug: string, topic?: string) => post<LiveTailStartResponse>('/api/snotra/live/start', { slug, topic }),
  liveStop: () => post<LiveTailStopResponse>('/api/snotra/live/stop', {}),
  mailAccounts: () => get<{ accounts: string[] }>('/api/mail/accounts'),
  mailQueue: (account: string, hours = 48) =>
    get<MailQueue>(`/api/mail/queue?account=${encodeURIComponent(account)}&hours=${hours}`),
  mailMessage: (account: string, id: string) =>
    get<MailMessage>(`/api/mail/message?account=${encodeURIComponent(account)}&id=${encodeURIComponent(id)}`),
};

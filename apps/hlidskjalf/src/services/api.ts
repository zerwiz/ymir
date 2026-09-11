import type {
  AgentCard,
  ChatMessage,
  FileNode,
  ProcessInfo,
  PullRequest,
  RecallEpisode,
  RealmId,
  RuneEntry,
  Task,
} from '../types';

/**
 * Gate API client (W0027 surface).
 *
 * Points at the local Hlidskjalf gate server (`apps/hlidskjalf/server`, default
 * :3889). In dev, Vite proxies `/api` to it, so an empty BASE works. Set
 * `VITE_API_URL` to override. This client is only used in live mode; demo mode
 * uses the seeded mocks.
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

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`, { credentials: 'include' });
  if (!res.ok) throw new Error(`${path} → ${res.status}`);
  return (await res.json()) as T;
}

async function post<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    credentials: 'include',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`${path} → ${res.status}`);
  return (await res.json()) as T;
}

export interface ChatReply {
  reply: ChatMessage;
  live: boolean;
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
  runtime: () => get<RuntimeInfo>('/api/runtime'),
  cron: () => get<CronInfo>('/api/cron'),
  loaders: () => get<LoaderRow[]>('/api/loaders'),
  checks: () => get<CheckRow[]>('/api/checks'),
  orders: () => get<OrdersInfo>('/api/orders'),
  chatHistory: () => get<ChatMessage[]>('/api/chat/history'),
  chat: (content: string) => post<ChatReply>('/api/chat', { content }),
};

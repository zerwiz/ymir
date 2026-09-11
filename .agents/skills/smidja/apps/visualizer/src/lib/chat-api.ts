/**
 * Client-side API for the orchestrator chat. Typed against the same contract
 * the server will expose once `/api/chat/*`, `/api/rosters` and `/api/models`
 * are mounted. Until then the store runs on sample data (`chatStore.demo`).
 */
import type {
  ChatHistoryResponse,
  ChatMessage,
  ChatMessageRequest,
  ChatMessageResponse,
  ModelsResponse,
  RosterInfo,
  RostersResponse,
  SessionStartRequest,
  SessionStartResponse,
  SessionSummary,
} from './types'

async function postJson<T>(url: string, body: unknown): Promise<T> {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new Error(`POST ${url} → ${res.status} ${text}`)
  }
  return (await res.json()) as T
}

async function getJson<T>(url: string): Promise<T> {
  const res = await fetch(url)
  if (!res.ok) throw new Error(`GET ${url} → ${res.status}`)
  return (await res.json()) as T
}

export function fetchChatHistory(sessionId: string): Promise<ChatHistoryResponse> {
  return getJson(`/api/chat/history?session=${encodeURIComponent(sessionId)}`)
}

/** All persisted chat sessions (multi-session switcher). */
export function fetchChatSessions(): Promise<{ id: string; messages: number; updated_at: string | null }[]> {
  return getJson('/api/chat/sessions')
}

/** Permanently delete a persisted chat conversation. */
export async function deleteChatSession(sessionId: string): Promise<void> {
  const res = await fetch(`/api/chat/session?session=${encodeURIComponent(sessionId)}`, {
    method: 'DELETE',
  })
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new Error(`DELETE /api/chat/session → ${res.status} ${text}`)
  }
}

export function sendChatMessage(req: ChatMessageRequest): Promise<ChatMessageResponse> {
  return postJson('/api/chat/message', req)
}

export function fetchRosters(): Promise<RostersResponse> {
  return getJson('/api/rosters')
}

/** Trace-db sessions. scope 'all' includes archived + plumbing one-shots. */
export function fetchSessionSummaries(scope: 'active' | 'all' = 'all'): Promise<SessionSummary[]> {
  return getJson(`/api/sessions?scope=${scope}`)
}

/** Stop / pause (SIGSTOP) / resume (SIGCONT) a live run via the trace-ui server. */
export function controlChatSession(
  adwId: string,
  action: 'stop' | 'pause' | 'resume',
): Promise<Record<string, unknown>> {
  return postJson(`/api/sessions/${encodeURIComponent(adwId)}/${action}`, {})
}

export function fetchRoster(name: string): Promise<RosterInfo> {
  return getJson(`/api/rosters/${encodeURIComponent(name)}`)
}

export function fetchModels(): Promise<ModelsResponse> {
  return getJson('/api/models')
}

export function startFactorySession(req: SessionStartRequest): Promise<SessionStartResponse> {
  return postJson('/api/chat/session', req)
}

export function steerChatSession(body: { adwId: string; message: string }): Promise<{ ok: boolean }> {
  return postJson('/api/chat/steer', body)
}

export type { ChatMessage }

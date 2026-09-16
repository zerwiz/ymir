import type {
  DecisionsResponse,
  Envelope,
  EventRow,
  EventsPage,
  GateResult,
  HealthResponse,
  MemoryHealth,
  MemoryInspect,
  MemoryRecall,
  MemoryTimeline,
  PromptsResponse,
  SessionDetail,
  SessionSummary,
  StatsResponse,
} from './types'

async function getJson(url: string): Promise<unknown> {
  const res = await fetch(url)
  if (!res.ok) throw new Error(`GET ${url} → ${res.status}`)
  return res.json()
}

export function fetchSessions(): Promise<SessionSummary[]> {
  return getJson('/api/sessions') as Promise<SessionSummary[]>
}

export async function fetchSession(adwId: string): Promise<SessionDetail> {
  const detail = (await getJson(`/api/sessions/${encodeURIComponent(adwId)}`)) as SessionDetail
  return {
    session: detail.session,
    usage: detail.usage ?? { read: 0, written: 0 },
    phases: detail.phases ?? [],
    agents: detail.agents ?? [],
  }
}

export async function fetchEvents(adwId: string, after: number, limit = 500): Promise<EventsPage> {
  const page = (await getJson(
    `/api/sessions/${encodeURIComponent(adwId)}/events?after=${after}&limit=${limit}`,
  )) as EventsPage | EventRow[]
  if (Array.isArray(page)) {
    const cursor = page.reduce((max, e) => Math.max(max, e.rowid), after)
    return { events: page, cursor, has_more: page.length === limit }
  }
  return { events: page.events ?? [], cursor: page.cursor ?? after, has_more: page.has_more ?? false }
}

/** Archive a run out of the review list (or restore it with archived=false). */
export async function archiveSession(adwId: string, archived = true): Promise<void> {
  const url = `/api/sessions/${encodeURIComponent(adwId)}/archive`
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ archived }),
  })
  if (!res.ok) throw new Error(`POST ${url} → ${res.status}`)
}

/** Stop a run — SIGTERM its live processes children-first. */
export async function stopSession(adwId: string): Promise<{ stopped: number; pids: number[] }> {
  const url = `/api/sessions/${encodeURIComponent(adwId)}/stop`
  const res = await fetch(url, { method: 'POST' })
  if (!res.ok) throw new Error(`POST ${url} → ${res.status}`)
  return (await res.json()) as { stopped: number; pids: number[] }
}

/** Pause a run — SIGSTOP the live agent children (hold mid-flight). */
export async function pauseSession(adwId: string): Promise<{ paused: number; pids: number[] }> {
  const url = `/api/sessions/${encodeURIComponent(adwId)}/pause`
  const res = await fetch(url, { method: 'POST' })
  if (!res.ok) throw new Error(`POST ${url} → ${res.status}`)
  return (await res.json()) as { paused: number; pids: number[] }
}

/** Resume a paused run — SIGCONT the agent children. */
export async function resumeSession(adwId: string): Promise<{ resumed: number; pids: number[] }> {
  const url = `/api/sessions/${encodeURIComponent(adwId)}/resume`
  const res = await fetch(url, { method: 'POST' })
  if (!res.ok) throw new Error(`POST ${url} → ${res.status}`)
  return (await res.json()) as { resumed: number; pids: number[] }
}

/** Steer a running run — inject an engineer message into the session. */
export async function steerSession(adwId: string, message: string): Promise<{ ok: boolean }> {
  const url = `/api/sessions/${encodeURIComponent(adwId)}/steer`
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ message }),
  })
  if (!res.ok) throw new Error(`POST ${url} → ${res.status}`)
  return (await res.json()) as { ok: boolean }
}

export function fetchHealth(): Promise<HealthResponse> {
  return getJson('/api/health') as Promise<HealthResponse>
}

export function fetchDecisions(): Promise<DecisionsResponse> {
  return getJson('/api/decisions') as Promise<DecisionsResponse>
}

export function fetchStats(): Promise<StatsResponse> {
  return getJson('/api/stats') as Promise<StatsResponse>
}

// PhaseDetail imports the prompts type from here alongside fetchPrompts.
export type { PromptsResponse }

export async function fetchPrompts(adwId: string, agent: string): Promise<PromptsResponse> {
  const res = await fetch(
    `/api/sessions/${encodeURIComponent(adwId)}/agents/${encodeURIComponent(agent)}/prompts`,
  )
  // Not recorded (or endpoint not deployed yet) renders as "no prompts", not an error.
  if (res.status === 404) return { system: null, user: null }
  if (!res.ok) throw new Error(`GET prompts → ${res.status}`)
  const data = (await res.json()) as Partial<PromptsResponse>
  return { system: data.system ?? null, user: data.user ?? null }
}

export function fetchEnvelopes(adwId: string): Promise<Envelope[]> {
  return getJson(`/api/sessions/${encodeURIComponent(adwId)}/envelopes`) as Promise<Envelope[]>
}

export function fetchGates(adwId: string): Promise<GateResult[]> {
  return getJson(`/api/sessions/${encodeURIComponent(adwId)}/gates`) as Promise<GateResult[]>
}

/** The model's thinking/reasoning text for an agent phase (pi streams). */
export async function fetchThinking(adwId: string, agent: string): Promise<string[]> {
  try {
    const res = await fetch(
      `/api/sessions/${encodeURIComponent(adwId)}/agents/${encodeURIComponent(agent)}/thinking`,
    )
    if (!res.ok) return []
    const data = (await res.json()) as { thinking?: string[] }
    return data.thinking ?? []
  } catch {
    return []
  }
}

// ── Kaia's memory (engram) ──────────────────────────────────────────────────

export function fetchMemoryHealth(): Promise<MemoryHealth> {
  return getJson('/api/memory/health') as Promise<MemoryHealth>
}

export function fetchMemoryInspect(): Promise<MemoryInspect> {
  return getJson('/api/memory/inspect') as Promise<MemoryInspect>
}

export function fetchMemoryRecall(q: string, k = 5, mode = 'hybrid'): Promise<MemoryRecall> {
  const params = new URLSearchParams({ q, k: String(k), mode })
  return getJson(`/api/memory/recall?${params}`) as Promise<MemoryRecall>
}

export function fetchMemoryTimeline(entity: string): Promise<MemoryTimeline> {
  const params = new URLSearchParams({ entity })
  return getJson(`/api/memory/timeline?${params}`) as Promise<MemoryTimeline>
}

export async function observeMemory(
  content: string,
  tags: string[],
  actors: string[],
  salience = 0.5,
): Promise<{ id: string }> {
  const res = await fetch('/api/memory/observe', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ content, tags, actors, salience }),
  })
  if (!res.ok) throw new Error(`POST /api/memory/observe → ${res.status}`)
  return (await res.json()) as { id: string }
}

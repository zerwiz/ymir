/**
 * Orchestrator chat state — a small reactive store (no Pinia), mirroring the
 * way the rest of the visualizer keeps state in component-local refs.
 *
 * All data comes from the real backend endpoints:
 *   GET  /api/rosters  /api/models   → picker (teams + orchestrator models)
 *   GET  /api/chat/history          → conversation for the active session
 *   POST /api/chat/message          → send to Kaia (Pi)
 *   POST /api/chat/session          → launch a smidja run
 *   POST /api/chat/steer            → inject guidance mid-run
 */
import { reactive, ref } from 'vue'
import type { ChatMessage, ModelInfo, RosterInfo, SessionLaunch, SessionStartRequest } from './types'
import {
  controlChatSession,
  deleteChatSession,
  fetchChatHistory,
  fetchChatSessions,
  fetchModels,
  fetchRosters,
  fetchSessionSummaries,
  sendChatMessage,
  startSmidjaSession,
  steerChatSession,
} from './chat-api'
import { fetchEvents, fetchSession } from './api'
import type { SessionDetail } from './types'

export const messages = ref<ChatMessage[]>([])
export const rosters = ref<RosterInfo[]>([])
export const models = ref<ModelInfo[]>([])

/** Models the chat pi process can actually resolve (pi --list-models catalog). */
export const chatModels = ref<{ id: string; name: string; provider: string }[]>([])

/** The model the chat talks to Kaia on; '' = server default (orchestrator cloud model). */
export const chatModel = ref('')
export const pending = ref(false)
export const error = ref<string | null>(null)
export const loaded = ref(false)

/** The active chat session id (persisted conversation on the server). */
export const sessionId = ref('default')

/** All persisted chat sessions, newest first (multi-session switcher). */
export const chatSessions = ref<{ id: string; messages: number; updated_at: string | null }[]>([])

/** The session the start-form / side panel is pointed at. */
export const activeSession = ref<SessionLaunch | null>(null)

/** All past runs from the trace db (scope=all), newest first — the "Past
 * sessions" list in the chat sidebar. Never filtered by admission/archive. */
export const pastSessions = ref<SessionLaunch[]>([])

export interface SidePanelState {
  panel: 'idle' | 'running' | 'completed'
  adwId: string | null
}

export const side = reactive<SidePanelState>({ panel: 'idle', adwId: null })

/** Real live stats for the active session, polled from the trace db. These
 * replace the old hardcoded ladder/cost/tokens in the sidebar's running panel
 * (mock-data cleanup left them canned). `null` until the first poll lands. */
export const liveStats = ref<{
  cost: number | null
  tokens: number | null
  toolCalls: number | null
  steps: { name: string; status: string }[]
} | null>(null)

/** Poll the trace db for the active session's real cost/tokens/phases. */
export async function refreshLiveStats(): Promise<void> {
  const adwId = activeSession.value?.smidja_id
  if (!adwId) return
  try {
    const detail = (await fetchSession(adwId)) as unknown as SessionDetail
    const s = detail.session
    const phases = detail.phases ?? []
    // Real tool-call count from the trace events (paginated; cap at 2 pages).
    let toolCalls = 0
    try {
      let after = 0
      for (let i = 0; i < 2; i++) {
        const page = await fetchEvents(adwId, after)
        toolCalls += page.events.filter((e) => e.type === 'tool_call').length
        if (!page.has_more) break
        after = page.cursor
      }
    } catch {
      /* best-effort — the detail fields still render */
    }
    const steps = (phases ?? []).map((p) => ({
      name: p.name ?? p.phase_id,
      status: p.status ?? 'queued',
    }))
    liveStats.value = {
      cost: s.total_cost ?? null,
      tokens: s.total_tokens ?? null,
      toolCalls,
      steps,
    }
  } catch (e) {
    liveStats.value = null
    error.value = (e as Error).message
  }
}

/** Load rosters + models for the picker. Called once on chat view mount. */
export async function init(): Promise<void> {
  error.value = null
  try {
    const [r, m, cm] = await Promise.all([
      fetchRosters(),
      fetchModels(),
      fetch('/api/chat/models').then((res) => res.json()),
    ])
    rosters.value = r
    models.value = m
    chatModels.value = cm as { id: string; name: string; provider: string }[]
    // Default Kaia to a WORKING local model when one is resolvable: prefer the
    // llamacpp Q2 (native, 130K) over a stale/cloud entry, so the first message
    // doesn't 500 with "Connection error" on an unloaded backend. Only applies
    // when the user hasn't already picked a model this session.
    if (!chatModel.value) {
      const q2 = (cm as { id: string; name: string; provider: string }[]).find(
        (m) => m.id === 'llamacpp/qwen3.6-35b-a3b@q2_k_xl',
      )
      if (q2) chatModel.value = q2.id
    }
    loaded.value = true
  } catch (e) {
    error.value = (e as Error).message
  }
}

/** Load the persisted conversation for the active session. */
export async function loadHistory(): Promise<void> {
  error.value = null
  try {
    messages.value = await fetchChatHistory(sessionId.value)
  } catch (e) {
    error.value = (e as Error).message
  }
}

/** Refresh the session switcher list. */
export async function loadChatSessions(): Promise<void> {
  try {
    chatSessions.value = await fetchChatSessions()
  } catch {
    /* best-effort — the switcher can stay empty */
  }
}

/** Switch to another persisted chat conversation. */
export async function switchChat(id: string): Promise<void> {
  if (id === sessionId.value) return
  sessionId.value = id
  activeSession.value = null
  side.panel = 'idle'
  side.adwId = null
  await loadHistory()
  await loadChatSessions()
}

/** Start a brand-new chat conversation with a fresh id. */
export async function newChat(): Promise<void> {
  const id = `chat-${Date.now().toString(36)}`
  sessionId.value = id
  messages.value = []
  activeSession.value = null
  side.panel = 'idle'
  side.adwId = null
  await loadChatSessions()
}

/** Permanently delete a chat conversation; switch to a fresh one. */
export async function deleteChat(id: string): Promise<void> {
  try {
    await deleteChatSession(id)
  } catch (e) {
    error.value = (e as Error).message
    return
  }
  if (id === sessionId.value) {
    await newChat()
  } else {
    await loadChatSessions()
  }
}

/** Send one chat message; await Kaia's reply and append both to the thread. */
export async function sendMessage(content: string): Promise<void> {
  const trimmed = content.trim()
  if (!trimmed || pending.value) return
  error.value = null

  messages.value.push({
    id: `u-${Date.now()}`,
    ts: new Date().toISOString(),
    role: 'user',
    content: trimmed,
  })

  pending.value = true
  const replyId = `k-${Date.now()}`
  messages.value.push({
    id: replyId,
    ts: new Date().toISOString(),
    role: 'kaia',
    content: '',
    streaming: true,
  })

  try {
    const res = await sendChatMessage({
      sessionId: sessionId.value,
      content: trimmed,
      model: chatModel.value.trim() || undefined,
    })
    const streamed = messages.value.find((m) => m.id === replyId)
    if (streamed) {
      streamed.streaming = false
      streamed.content = res.message.content
      streamed.tool_calls = res.message.tool_calls
      streamed.model = res.message.model
    }
  } catch (e) {
    error.value = (e as Error).message
    const streamed = messages.value.find((m) => m.id === replyId)
    if (streamed) {
      streamed.streaming = false
      streamed.role = 'error'
      streamed.content = `Kaia is offline — ${(e as Error).message}`
    }
  } finally {
    pending.value = false
  }
}

/** Launch a smidja session from the start form. */
export async function launchSession(req: SessionStartRequest): Promise<SessionLaunch> {
  error.value = null
  const res = await startSmidjaSession(req)
  const launch: SessionLaunch = {
    smidja_id: res.smidja_id,
    team: res.roster,
    model: res.model,
    status: 'running',
  }
  messages.value.push({
    id: `l-${Date.now()}`,
    ts: new Date().toISOString(),
    role: 'kaia',
    content: `Launching **${res.roster}** against the task.`,
    session_launch: launch,
    model: res.model,
  })
  activeSession.value = launch
  side.panel = 'running'
  side.adwId = launch.smidja_id
  return launch
}

/** Load every run (scope=all) into pastSessions, newest first, mapped to
 * SessionLaunch for the sidebar's SessionMiniCards. */
export async function loadPastSessions(): Promise<void> {
  error.value = null
  try {
    const all = await fetchSessionSummaries('all')
    const activeId = activeSession.value?.smidja_id
    pastSessions.value = all
      .filter((s) => s.smidja_id !== activeId)
      .map((s) => ({
        smidja_id: s.smidja_id,
        team: s.smidja_name ?? 'smidja',
        model: s.model ?? '',
        status: s.status,
      }))
  } catch (e) {
    error.value = (e as Error).message
  }
}

/** Stop / pause / resume the active live session via the trace-ui server. */
export async function controlActive(action: 'stop' | 'pause' | 'resume'): Promise<void> {
  const adwId = activeSession.value?.smidja_id
  if (!adwId) return
  error.value = null
  try {
    await controlChatSession(adwId, action)
    if (action === 'stop') {
      if (activeSession.value) activeSession.value.status = 'fail'
      side.panel = 'completed'
      side.adwId = adwId
    }
    await loadPastSessions()
  } catch (e) {
    error.value = (e as Error).message
  }
}

/** Auto-attach a detached/terminal-launched running session to the chat: when
 * the trace db shows a live run we did not start from this chat, surface it as
 * a launch card + point the sidebar at it. Covers "terminal-launched runs were
 * invisible in Orchestrator Chat". */
export async function syncAutoAttach(): Promise<void> {
  error.value = null
  try {
    const all = await fetchSessionSummaries('all')
    const live = all.find((s) => s.status === 'running' && s.smidja_id !== activeSession.value?.smidja_id)
    await loadPastSessions()
    if (!live) return
    const launch: SessionLaunch = {
      smidja_id: live.smidja_id,
      team: live.smidja_name ?? 'smidja',
      model: live.model ?? '',
      status: 'running',
    }
    if (!messages.value.some((m) => m.session_launch?.smidja_id === live.smidja_id)) {
      messages.value.push({
        id: `auto-${Date.now()}`,
        ts: new Date().toISOString(),
        role: 'kaia',
        content: `Detected a running session **${live.smidja_id}** on the trace db.`,
        session_launch: launch,
        model: live.model ?? '',
      })
    }
    if (!activeSession.value) {
      activeSession.value = launch
      side.panel = 'running'
      side.adwId = live.smidja_id
    }
  } catch (e) {
    error.value = (e as Error).message
  }
}

/** Inject guidance into the active running session. */
export async function steerActive(message: string): Promise<void> {
  const adwId = activeSession.value?.smidja_id
  if (!adwId || !message.trim()) return
  error.value = null
  try {
    await steerChatSession({ adwId, message })
  } catch (e) {
    error.value = (e as Error).message
  }
}

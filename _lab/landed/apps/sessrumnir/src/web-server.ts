/**
 * Sessrúmnir web server — Bun.serve implementing the bridge over HTTP + WS.
 *
 * Reuses the main-process logic (WorkspaceManager, PiRpcManager, etc.)
 * instead of reimplementing it. The transport differs:
 *   - HTTP POST /api/<channel> for request/response
 *   - WebSocket /ws/<channel> for event subscriptions
 *   - Static files for the built renderer
 *
 * This file is the web shell's origin. It serves the built renderer
 * and the bridge API on the same port.
 *
 * NOTE: This server runs in Bun (not Electron), so it cannot import
 * Electron modules. It only imports pure logic modules from src/main/.
 */

import { WorkspaceManager } from './main/workspace-manager'
import { readFile } from 'node:fs/promises'
import { SessionTagManager } from './main/session-tags'
import { ArchivedSessionsManager } from './main/archived-sessions'
import { TerminalService } from './main/terminal-service'
import { NotesManager } from './main/notes-manager'
import { loadAppSettings, saveAppSettings } from './main/settings-logic'
import type { IpcContext } from './main/ipc/context'
import type { PiRpcManager } from './main/pi-rpc-manager'
import type { AppSettings } from './shared/ipc-contracts'

// ─── WebSocket client registry ──────────────────────────────────────────────

interface WsClient {
  ws: WebSocket
  id: string
}

const clients: WsClient[] = []

// ─── Adapted IPC context for web ────────────────────────────────────────────

function createWebIpcContext(workspaceManager: WorkspaceManager): IpcContext {
  const tagManager = new SessionTagManager() as unknown as SessionTagManager
  const archivedSessions = new ArchivedSessionsManager() as unknown as ArchivedSessionsManager
  const terminalService = new TerminalService() as unknown as TerminalService
  const notesManager = new NotesManager() as unknown as NotesManager

  const approvedAttachmentPaths = new Set<string>()

  function getActivePi(): PiRpcManager {
    const pi = workspaceManager.getActivePiManager()
    if (!pi) throw new Error('No active workspace or Pi not running')
    return pi
  }

  // Broadcast to all connected WebSocket clients instead of Electron windows
  function broadcast(channel: string, data: unknown): void {
    for (const client of clients) {
      if (client.ws.readyState === WebSocket.OPEN) {
        client.ws.send(JSON.stringify({ channel, data }))
      }
    }
  }

  return {
    workspaceManager,
    broadcast,
    getActivePi,
    approvedAttachmentPaths,
    tagManager,
    archivedSessions,
    notesManager,
    terminalService,
  }
}

// ─── Server state ───────────────────────────────────────────────────────────

let workspaceManager: WorkspaceManager | null = null
let ipcContext: IpcContext | null = null

// ─── Static file serving ────────────────────────────────────────────────────

const CONTENT_TYPES: Record<string, string> = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
}

async function serveStaticFile(filepath: string): Promise<Response | null> {
  try {
    const ext = filepath.substring(filepath.lastIndexOf('.')).toLowerCase()
    const contentType = CONTENT_TYPES[ext] || 'application/octet-stream'

    // Read from out/renderer/ (the electron-vite build output)
    const fullPath = `${process.cwd()}/out/renderer${filepath}`
    const file = Bun.file(fullPath)
    const bytes = await file.bytes()

    return new Response(bytes, {
      headers: { 'Content-Type': contentType },
    })
  } catch (err) {
    console.error('[Sessrúmnir Web] Failed to serve static file:', filepath, err)
    return null // file not found
  }
}

// ─── HTTP handler ───────────────────────────────────────────────────────────

async function handleRequest(req: Request): Promise<Response> {
  const url = new URL(req.url)

  // ── Serve static files (built renderer) ────────────────────────────────
  if (req.method === 'GET') {
    const pathname = url.pathname

    // HTML entry point — serve index.html
    if (pathname === '/' || pathname.endsWith('.html')) {
      const filePath = pathname === '/' ? '/index.html' : pathname
      const res = await serveStaticFile(filePath)
      if (res) return res
    }

    // JS/CSS/assets — serve from out/renderer/
    if (pathname.match(/\.(js|css|mjs|png|svg|woff|woff2|ttf)$/)) {
      const res = await serveStaticFile(pathname)
      if (res) return res
    }

    // For any other GET, try to serve as static file
    const res = await serveStaticFile(pathname)
    if (res) return res
  }

  // ── API endpoint (POST /api/<channel>) ─────────────────────────────────
  if (req.method === 'POST' && url.pathname.startsWith('/api/')) {
    const channel = url.pathname.replace(/^\/api\//, '')

    if (!ipcContext) {
      return new Response('Server not initialized', { status: 503 })
    }

    try {
      const body = await req.json()
      const args = Array.isArray(body) ? body : [body]

      // Route to the appropriate handler
      const result = await routeToHandler(channel, args)
      return new Response(JSON.stringify(result), {
        headers: { 'Content-Type': 'application/json' },
      })
    } catch (err) {
      return new Response(JSON.stringify({ error: String(err) }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }
  }

  // ── 404 ────────────────────────────────────────────────────────────────
  return new Response('Not found', { status: 404 })
}

// ─── The seat wire (plan 231) ────────────────────────────────────────────────

/**
 * A seat is one workspace plus the agent session it runs. Three channels are the
 * whole wire — list the seats, hand one a line, read the last answer it gave — and
 * `bin/seat/sessrumnir-wire.sh` is the door that speaks them, so a voice or another
 * agent can reach a seat someone opened by hand.
 */
function seatById(id: string | undefined): { id: string; name: string; path: string } | null {
  if (!workspaceManager) return null
  if (!id || id === 'active') return workspaceManager.getActiveWorkspace()
  const seats = workspaceManager.getWorkspaces()
  return seats.find((s) => s.id === id || s.name === id || s.path === id) ?? null
}

/**
 * The last assistant text recorded in a session file. Read from pi's own transcript
 * (JSONL, one entry per line) rather than from a remembered copy, so the answer is
 * the session's, not this server's idea of it.
 */
async function readLastAssistantText(sessionPath: string): Promise<string> {
  try {
    const raw = await readFile(sessionPath, 'utf8')
    let text = ''
    for (const line of raw.split('\n')) {
      const trimmed = line.trim()
      if (!trimmed) continue
      let entry: any
      try {
        entry = JSON.parse(trimmed)
      } catch {
        continue
      }
      if (entry?.type !== 'message' || entry?.message?.role !== 'assistant') continue
      const content = entry.message.content
      const parts: string[] =
        typeof content === 'string'
          ? [content]
          : Array.isArray(content)
            ? content.filter((c: any) => c?.type === 'text' && typeof c.text === 'string').map((c: any) => c.text)
            : []
      const joined = parts.join('\n').trim()
      if (joined) text = joined
    }
    return text
  } catch {
    return ''
  }
}

// ─── Handler routing ────────────────────────────────────────────────────────

/**
 * Route an API call to the appropriate handler function.
 * This mirrors what the IPC handlers do, but calls them directly.
 */
async function routeToHandler(channel: string, args: unknown[]): Promise<unknown> {
  if (!ipcContext || !workspaceManager) {
    throw new Error('Server not initialized')
  }

  const { workspaceManager: wm } = ipcContext

  // ── Pi process lifecycle ───────────────────────────────────────────────
  if (channel === 'pi:start') {
    const activeWs = wm.getActiveWorkspace()
    if (!activeWs) throw new Error('No active workspace')
    const pi = wm.getActivePiManager()
    if (!pi) throw new Error('No Pi manager')
    return pi.getStatus()
  }

  if (channel === 'pi:stop') {
    const activeWs = wm.getActiveWorkspace()
    if (activeWs) wm.stopPiForWorkspace(activeWs.id)
    return { status: 'stopped', pid: null, error: null }
  }

  if (channel === 'pi:restart') {
    const activeWs = wm.getActiveWorkspace()
    if (!activeWs) throw new Error('No active workspace')
    const pi = wm.getPiManager(activeWs.id)
    if (!pi) throw new Error('No Pi manager')
    pi.stop()
    return { status: 'stopped', pid: null, error: null }
  }

  if (channel === 'pi:status') {
    const activeWs = wm.getActiveWorkspace()
    if (!activeWs) return { status: 'stopped', pid: null, error: null }
    const pi = wm.getActivePiManager()
    if (!pi) return { status: 'stopped', pid: null, error: null }
    return pi.getStatus()
  }

  if (channel === 'pi:detect-installations') {
    // Simplified: return empty
    return { installations: [] }
  }

  // ── Session management ─────────────────────────────────────────────────
  if (channel === 'session:list') {
    const cwd = args[0] as string | undefined
    return wm.listSessions(cwd)
  }

  if (channel === 'session:list-all') {
    const cwd = args[0] as string | undefined
    return wm.listSessions(cwd, true)
  }

  // ── Settings ───────────────────────────────────────────────────────────
  if (channel === 'settings:get-all') {
    return await loadAppSettings(wm)
  }

  if (channel === 'settings:save') {
    const settings = args[0] as Partial<AppSettings>
    await saveAppSettings(settings)
    return await loadAppSettings(wm)
  }

  // ── Workspace management ───────────────────────────────────────────────
  if (channel === 'workspace:list') {
    return wm.getWorkspaces()
  }

  if (channel === 'workspace:get-active') {
    return wm.getActiveWorkspace()
  }

  // ── File operations ────────────────────────────────────────────────────
  if (channel === 'file:tree') {
    const _maxDepth = (args[0] as number) || 2
    // Simplified: return empty tree
    return { name: '', path: '', type: 'directory' as const, children: [] }
  }

  // ── The seat wire: enumerate, hand a line, read the answer (plan 231) ──
  if (channel === 'seat:list') {
    const activeId = wm.getActiveWorkspaceId()
    return wm.getWorkspaces().map((ws) => {
      const pi = wm.getPiManager(ws.id)
      const status = pi ? pi.getStatus() : null
      return {
        id: ws.id,
        name: ws.name,
        path: ws.path,
        active: ws.id === activeId,
        status: status ? status.status : 'stopped',
        pid: status ? status.pid : null,
      }
    })
  }

  if (channel === 'seat:prompt') {
    const seatArg = args[0] as string | undefined
    const message = args[1] as string | undefined
    if (typeof message !== 'string' || !message.trim()) throw new Error('seat:prompt needs a line to send')
    const seat = seatById(seatArg)
    if (!seat) throw new Error(`no seat named ${seatArg ?? 'active'} — call seat:list`)
    const pi = wm.getPiManager(seat.id)
    if (!pi) throw new Error(`seat ${seat.name} holds no live agent — start it in Sessrúmnir first`)
    await pi.sendCommand({ type: 'prompt', message })
    return { sent: true, seat: seat.name }
  }

  if (channel === 'seat:last-answer') {
    const seatArg = args[0] as string | undefined
    const charsArg = args[1] as number | undefined
    const seat = seatById(seatArg)
    if (!seat) throw new Error(`no seat named ${seatArg ?? 'active'} — call seat:list`)
    const limit = typeof charsArg === 'number' && charsArg > 0 ? charsArg : 900
    const sessions = await wm.listSessions(seat.path)
    const newest = Array.isArray(sessions) && sessions.length > 0 ? sessions[0] : null
    if (!newest) return { seat: seat.name, text: '', detail: 'that seat has no session on disk yet' }
    const answer = await readLastAssistantText(newest.path)
    return {
      seat: seat.name,
      at: newest.lastModified ? new Date(newest.lastModified).toISOString() : '',
      text: answer.slice(-limit),
      detail: answer ? '' : 'no assistant answer is recorded in the newest session yet',
    }
  }

  // ── Default: unknown channel ───────────────────────────────────────────
  return { error: `Unknown channel: ${channel}` }
}

// ─── WebSocket handler ──────────────────────────────────────────────────────

function _handleWebSocket(_ws: WebSocket): void {
  const id = crypto.randomUUID()
  clients.push({ ws: _ws, id })

  _ws.addEventListener('close', () => {
    const idx = clients.findIndex((c) => c.id === id)
    if (idx >= 0) clients.splice(idx, 1)
  })

  _ws.addEventListener('message', (_event) => {
    const _msg = JSON.parse(_event.data.toString())
    // Forward messages to the appropriate handler
    // This is a simplified approach for now
  })
}

// ─── Start the server ───────────────────────────────────────────────────────

export async function startWebServer(port: number = 3890): Promise<void> {
  try {
    // Initialize workspace manager (same as main process)
    workspaceManager = new WorkspaceManager()
    await workspaceManager.initialize()
    console.log('[Sessrúmnir Web] WorkspaceManager initialized')

    // Create adapted IPC context
    ipcContext = createWebIpcContext(workspaceManager)
    console.log('[Sessrúmnir Web] IPC context created')

    // Start Bun server
    const server = Bun.serve({
      port,
      fetch: handleRequest,
      websocket: {
        message(_ws, _message) {
          // Handle WebSocket messages
        },
      },
    })

    console.log(`[Sessrúmnir Web] Listening on http://127.0.0.1:${port}`)
    
    // Keep the process alive by preventing exit
    const keepAlive = setInterval(() => {}, 60000)
    keepAlive.unref()
    
    // Also prevent exit via stdin close
    process.stdin.resume()
    
    return server
  } catch (err) {
    console.error('[Sessrúmnir Web] Failed to start:', err)
    process.exit(1)
  }
}

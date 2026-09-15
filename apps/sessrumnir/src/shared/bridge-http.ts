/**
 * HTTP/WS bridge client — implements PiDesktopAPI over HTTP + WebSocket.
 *
 * Used by the web shell (non-Electron). The renderer calls `window.piDesktop`
 * which is this client; the Electron preload swaps in the IPC version.
 *
 * Transport decisions:
 *   - Synchronous methods (getPathForFile, platform) → return stubs or null
 *   - Request/response methods → POST /api/<channel> with JSON body
 *   - Event subscriptions → WebSocket /ws/<channel> with SSE-like streaming
 *   - Terminal data → WebSocket /ws/terminal (bidirectional)
 */

import type { PiDesktopAPI } from './bridge'
import type {
  PiRpcEvent,
  PendingPromptCounts,
  WorkspaceActivityMap,
  SessionRuntimeInfo,
  WorkspaceActivationIntent,
  FileChangeEvent,
  CouncilProgressEvent,
  TerminalExitEvent,
} from './ipc-contracts'

// ─── HTTP Bridge Client ─────────────────────────────────────────────────────

const BASE = '' // relative to the web server root
const WS_BASE = '' // relative to the web server origin

/**
 * Create an HTTP/WS bridge client. Call `connect()` to establish the
 * WebSocket connection for event subscriptions.
 */
export function createHttpBridge(): PiDesktopAPI {
  type SubscriptionEntry = { ws: WebSocket; handler: (event: MessageEvent) => void }
  const subscriptions = new Map<string, SubscriptionEntry[]>()

  // ── Helper: HTTP POST to /api/<channel> ────────────────────────────────
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  async function invoke(channel: string, ...args: unknown[]): Promise<any> {
    const body = args.length === 1 ? args[0] : args
    const res = await fetch(`${BASE}/api/${channel}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    if (!res.ok) {
      const text = await res.text().catch(() => '')
      throw new Error(`HTTP ${res.status}: ${text}`)
    }
    return res.json()
  }

  // ── Helper: WebSocket subscription ─────────────────────────────────────
  function subscribe(channel: string, callback: (...args: unknown[]) => void): () => void {
    const ws = new WebSocket(`${WS_BASE}/ws/${channel}`)
    const handler = (event: MessageEvent) => {
      const data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data
      callback(data)
    }
    ws.addEventListener('message', handler)
    const entry: SubscriptionEntry = { ws, handler }
    const existing = subscriptions.get(channel) || []
    existing.push(entry)
    subscriptions.set(channel, existing)
    return () => {
      const subs = subscriptions.get(channel)
      if (subs) {
        const idx = subs.indexOf(entry)
        if (idx >= 0) subs.splice(idx, 1)
        ws.close()
      }
    }
  }

  // ── Pi process lifecycle ───────────────────────────────────────────────
  const pi = {
    start: (options?: Parameters<PiDesktopAPI['pi']['start']>[0]) => invoke('pi:start', options),
    stop: () => invoke('pi:stop'),
    restart: (options?: Parameters<PiDesktopAPI['pi']['restart']>[0]) => invoke('pi:restart', options),
    getStatus: () => invoke('pi:status'),
    detectInstallations: (options?: Parameters<PiDesktopAPI['pi']['detectInstallations']>[0]) => invoke('pi:detect-installations', options),
  }

  // ── Pi commands ────────────────────────────────────────────────────────
  const commands = {
    prompt: (message: string, options?: { images?: unknown[]; streamingBehavior?: string }) => invoke('pi:prompt', message, options),
    steer: (message: string, images?: unknown[]) => invoke('pi:steer', message, images),
    followUp: (message: string) => invoke('pi:follow-up', message),
    abort: () => invoke('pi:abort'),
    bash: (command: string) => invoke('pi:bash', command),
    abortBash: () => invoke('pi:abort-bash'),
  }

  // ── Session management ─────────────────────────────────────────────────
  const session = {
    createNew: () => invoke('session:new'),
    launchTask: (options: Parameters<PiDesktopAPI['session']['launchTask']>[0]) => invoke('session:launch-task', options),
    closeRuntime: (runtimeId: string) => invoke('session:close-runtime', runtimeId),
    switch: (sessionPath: string, cwd?: string) => invoke('session:switch', sessionPath, cwd),
    listRuntimes: () => invoke('session:list-runtimes'),
    fork: (entryId?: string) => invoke('session:fork', entryId),
    clone: () => invoke('session:clone'),
    list: (cwd?: string) => invoke('session:list', cwd),
    listAll: (cwd?: string) => invoke('session:list-all', cwd),
    getState: () => invoke('session:get-state'),
    getMessages: () => invoke('session:get-messages'),
    getStats: () => invoke('session:get-stats'),
    setName: (name: string) => invoke('session:set-name', name),
    exportHtml: (outputPath?: string) => invoke('session:export-html', outputPath),
    getForkMessages: () => invoke('session:get-fork-messages'),
    delete: (sessionPath: string) => invoke('session:delete', sessionPath),
    archive: (sessionId: string) => invoke('session:archive', sessionId),
    unarchive: (sessionId: string) => invoke('session:unarchive', sessionId),
    listArchived: () => invoke('session:list-archived'),
    getLineage: () => invoke('session:get-lineage'),
    compact: (customInstructions?: string) => invoke('session:compact', customInstructions),
  }

  // ── Model management ───────────────────────────────────────────────────
  const model = {
    set: (provider: string, modelId: string) => invoke('model:set', provider, modelId),
    cycle: () => invoke('model:cycle'),
    listAvailable: () => invoke('model:list-available'),
  }

  // ── Thinking ───────────────────────────────────────────────────────────
  const thinking = {
    setLevel: (level: string) => invoke('thinking:set-level', level),
    cycleLevel: () => invoke('thinking:cycle-level'),
  }

  // ── Settings ───────────────────────────────────────────────────────────
  const settings = {
    getAll: () => invoke('settings:get-all'),
    save: (s: Parameters<PiDesktopAPI['settings']['save']>[0]) => invoke('settings:save', s),
  }

  // ── Permission rules ───────────────────────────────────────────────────
  const permissionRules = {
    get: (scope: Parameters<PiDesktopAPI['permissionRules']['get']>[0]) => invoke('permission-rules:get', scope),
    set: (scope: Parameters<PiDesktopAPI['permissionRules']['set']>[0], rules: Parameters<PiDesktopAPI['permissionRules']['set']>[1]) => invoke('permission-rules:set', scope, rules),
    importFromFile: () => invoke('permission-rules:import'),
    exportToFile: (rules: Parameters<PiDesktopAPI['permissionRules']['exportToFile']>[0]) => invoke('permission-rules:export', rules),
    workspaceStatus: () => invoke('permission-rules:workspace-status'),
    removeWorkspace: () => invoke('permission-rules:remove-workspace'),
    setWorkspaceTrust: (trusted: boolean) => invoke('permission-rules:set-workspace-trust', trusted),
  }

  // ── Themes ─────────────────────────────────────────────────────────────
  const themes = {
    list: () => invoke('themes:list'),
    save: (file: Parameters<PiDesktopAPI['themes']['save']>[0], existingId?: string) => invoke('themes:save', file, existingId),
    delete: (id: string) => invoke('themes:delete', id),
    installFromUrl: (url: string) => invoke('themes:install-from-url', url),
    export: (file: Parameters<PiDesktopAPI['themes']['export']>[0]) => invoke('themes:export', file),
    import: () => invoke('themes:import'),
    gallery: () => invoke('themes:gallery-list'),
    galleryImage: (url: string) => invoke('themes:gallery-image', url),
  }

  // ── Workspace management ───────────────────────────────────────────────
  const workspace = {
    list: () => invoke('workspace:list'),
    create: (name: string, path: string) => invoke('workspace:create', name, path),
    createTab: (options?: Parameters<PiDesktopAPI['workspace']['createTab']>[0]) => invoke('workspace:create-tab', options),
    remove: (workspaceId: string) => invoke('workspace:remove', workspaceId),
    rename: (workspaceId: string, name: string) => invoke('workspace:rename', workspaceId, name),
    changePath: (workspaceId: string, newPath: string) => invoke('workspace:change-path', workspaceId, newPath),
    pathExists: () => invoke('workspace:path-exists'),
    setActive: (workspaceId: string) => invoke('workspace:set-active', workspaceId),
    getActive: () => invoke('workspace:get-active'),
    startPi: (workspaceId: string, options?: Parameters<PiDesktopAPI['workspace']['startPi']>[1]) => invoke('workspace:start-pi', workspaceId, options),
    stopPi: (workspaceId: string) => invoke('workspace:stop-pi', workspaceId),
    getActivity: () => invoke('workspace:activity'),
    takePendingActivation: () => invoke('workspace:take-pending-activation'),
  }

  // ── Package management ─────────────────────────────────────────────────
  const packages = {
    listInstalled: () => invoke('package:list-installed'),
    install: (spec: string) => invoke('package:install', spec),
    remove: (spec: string) => invoke('package:remove', spec),
    update: (spec?: string) => invoke('package:update', spec),
    updateAll: () => invoke('package:update-all'),
    checkUpdates: () => invoke('package:check-updates'),
    fetchCatalog: (query?: string) => invoke('package:catalog-fetch', query),
  }

  // ── Models config ──────────────────────────────────────────────────────
  const models = {
    read: () => invoke('models:read'),
    write: (config: Parameters<PiDesktopAPI['models']['write']>[0]) => invoke('models:write', config),
  }

  // ── Council ────────────────────────────────────────────────────────────
  const council = {
    detect: () => invoke('council:detect'),
    runConsultants: (payload: Parameters<PiDesktopAPI['council']['runConsultants']>[0]) => invoke('council:run-consultants', payload),
    arbiter: (payload: Parameters<PiDesktopAPI['council']['arbiter']>[0]) => invoke('council:arbiter', payload),
    onProgress: (callback: (event: CouncilProgressEvent) => void) => subscribe('event:council-progress', callback as (...args: unknown[]) => void),
  }

  // ── Skills, Commands, MCP, Tags ────────────────────────────────────────
  const skills = { list: () => invoke('skills:list') }
  const piCommands = { list: () => invoke('commands:list') }
  const mcpServers = { list: () => invoke('mcp:servers-list') }
  const tags = {
    get: (sessionId: string) => invoke('tag:get', sessionId),
    set: (sessionId: string, tags: string[]) => invoke('tag:set', sessionId, tags),
    add: (sessionId: string, tag: string) => invoke('tag:add', sessionId, tag),
    remove: (sessionId: string, tag: string) => invoke('tag:remove', sessionId, tag),
    getAll: () => invoke('tag:get-all'),
    getAllUsed: () => invoke('tag:get-all-used'),
    autoGetAll: () => invoke('tag:auto-get-all'),
    autoEnsure: (sessions: Array<{ sessionId: string; path: string }>) => invoke('tag:auto-ensure', sessions),
    autoRemove: (sessionId: string) => invoke('tag:auto-remove', sessionId),
  }

  // ── Git conveyor ───────────────────────────────────────────────────────
  const git = {
    status: () => invoke('git:conveyor-status'),
    commit: (options: Parameters<PiDesktopAPI['git']['commit']>[0]) => invoke('git:conveyor-commit', options),
    push: () => invoke('git:conveyor-push'),
    createPullRequest: (options: Parameters<PiDesktopAPI['git']['createPullRequest']>[0]) => invoke('git:conveyor-create-pr', options),
  }

  // ── Notes ──────────────────────────────────────────────────────────────
  const notes = {
    list: () => invoke('notes:list'),
    create: (input: Parameters<PiDesktopAPI['notes']['create']>[0]) => invoke('notes:create', input),
    update: (id: string, patch: Parameters<PiDesktopAPI['notes']['update']>[1]) => invoke('notes:update', id, patch),
    remove: (id: string) => invoke('notes:remove', id),
  }

  // ── File operations ────────────────────────────────────────────────────
  const files = {
    getTree: (maxDepth?: number) => invoke('file:tree', maxDepth),
    search: (query: string) => invoke('file:search', query),
    searchContent: (query: string) => invoke('file:search-content', query),
    read: (path: string) => invoke('file:read', path),
    readAttachment: (path: string) => invoke('file:read-attachment', path),
    write: (path: string, content: string) => invoke('file:write', path, content),
    getDiff: (filePath?: string) => invoke('file:diff', filePath),
    getStagedDiff: (filePath?: string) => invoke('file:staged-diff', filePath),
    getGitStatus: () => invoke('git:status'),
    getGitBranch: () => invoke('git:branch'),
  }

  // ── System ─────────────────────────────────────────────────────────────
  const system = {
    openDialog: (options?: Parameters<PiDesktopAPI['system']['openDialog']>[0]) => invoke('system:open-dialog', options),
    getPath: (name: string) => invoke('system:get-path', name),
    getPathForFile: (_file: File) => '', // NOT PORTABLE: requires webUtils.getPathForFile
    pathKind: (path: string) => invoke('system:path-kind', path),
    openExternal: (url: string) => invoke('system:open-external', url),
    hallUrl: () => invoke('system:hall-url'),
    getVersion: () => invoke('system:get-version'),
    get platform() { return 'linux' as NodeJS.Platform }, // stub: web has no process.platform
  }

  // ── Activity stats ─────────────────────────────────────────────────────
  const activity = {
    getStats: () => invoke('activity:get-stats'),
  }

  // ── Workflow run monitoring ────────────────────────────────────────────
  const workflows = {
    list: () => invoke('workflow:list'),
    getRun: (workspaceId: string, runId: string) => invoke('workflow:get-run', workspaceId, runId),
    control: (workspaceId: string, runId: string, action: Parameters<PiDesktopAPI['workflows']['control']>[2]) => invoke('workflow:control', workspaceId, runId, action),
    setPersistAgentSessions: (enabled: boolean) => invoke('workflow:set-persistence', enabled),
  }

  // ── Diagnostics ────────────────────────────────────────────────────────
  const diagnostics = {
    get: () => invoke('diagnostics:get'),
  }

  // ── Update check ───────────────────────────────────────────────────────
  const updates = {
    check: () => invoke('update:check'),
  }

  // ── i18n environment ───────────────────────────────────────────────────
  const i18n = {
    getEnvironment: () => invoke('i18n:get-environment'),
  }

  // ── Terminal ───────────────────────────────────────────────────────────
  const terminal = {
    start: (options?: Parameters<PiDesktopAPI['terminal']['start']>[0]) => invoke('terminal:start', options),
    input: (data: string) => invoke('terminal:input', data),
    resize: (cols: number, rows: number) => invoke('terminal:resize', { cols, rows }),
    stop: () => invoke('terminal:stop'),
    onData: (callback: (data: string) => void) => subscribe('event:terminal-data', callback as (...args: unknown[]) => void),
    onExit: (callback: (event: TerminalExitEvent) => void) => subscribe('event:terminal-exit', callback as (...args: unknown[]) => void),
  }

  // ── Extension UI responses ─────────────────────────────────────────────
  const ui = {
    respondSelect: (id: string, value: string) => invoke('ui:select-response', id, value),
    respondConfirm: (id: string, confirmed: boolean) => invoke('ui:confirm-response', id, confirmed),
    respondInput: (id: string, value: string) => invoke('ui:input-response', id, value),
    respondEditor: (id: string, value: string) => invoke('ui:editor-response', id, value),
    flushPendingPrompts: (workspaceId: string) => invoke('ui:pending-flush', workspaceId),
    getPendingPrompts: () => invoke('ui:pending-get'),
    setEditorDirty: (_dirty: boolean, _fileName: string | null) => {
      // NOT PORTABLE: requires ipcRenderer.send (fire-and-forget IPC)
      // The web server tracks dirty state via a separate endpoint
    },
  }

  // ── Event subscriptions ────────────────────────────────────────────────
  const onEvent = (callback: (event: PiRpcEvent) => void) =>
    subscribe('event:pi', callback as (...args: unknown[]) => void)
  const onPendingPrompts = (callback: (counts: PendingPromptCounts) => void) =>
    subscribe('event:pending-prompts', callback as (...args: unknown[]) => void)
  const onWorkspaceActivity = (callback: (map: WorkspaceActivityMap) => void) =>
    subscribe('event:workspace-activity', callback as (...args: unknown[]) => void)
  const onSessionRuntime = (callback: (runtime: SessionRuntimeInfo) => void) =>
    subscribe('event:session-runtime', callback as (...args: unknown[]) => void)
  const onActivateWorkspace = (callback: (payload: WorkspaceActivationIntent) => void) =>
    subscribe('event:activate-workspace', callback as (...args: unknown[]) => void)
  const onFileChange = (callback: (event: FileChangeEvent) => void) =>
    subscribe('event:file-change', callback as (...args: unknown[]) => void)
  const onMenuAction = (_callback: (action: string) => void) => {
    // NOT PORTABLE: menu actions are Electron menu clicks; web has no menu bar
    return () => {}
  }

  return {
    pi, commands, session, model, thinking, settings, permissionRules,
    themes, workspace, packages, models, council, skills, piCommands,
    mcpServers, tags, git, notes, files, system, activity, workflows,
    diagnostics, updates, i18n, terminal, ui,
    onEvent, onPendingPrompts, onWorkspaceActivity, onSessionRuntime,
    onActivateWorkspace, onFileChange, onMenuAction,
  }
}

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
  PiStatus,
  SessionListItem,
  SessionDeleteResult,
  ArchivedSessionsMap,
  AppSettings,
  AgentDetectionOptions,
  AgentInstallationsResult,
  Workspace,
  WorkspaceRemoveResult,
  InstalledPackage,
  InstalledSkill,
  CatalogPackage,
  FileTreeNode,
  FileSearchResult,
  FileChangeEvent,
  TerminalExitEvent,
  TerminalStartResult,
  Note,
  UpdateCheckResult,
  SessionLineageRecord,
  ModelsConfig,
  ModelsReadResult,
  CouncilDetectResult,
  CouncilRunRequest,
  CouncilRunResult,
  CouncilArbiterRequest,
  CouncilProgressEvent,
  AttachmentReadResult,
  OpenDialogOptions,
  PathKindResult,
  PromptImage,
  ActivityStatsResult,
  DiagnosticsReport,
  ThemesListResult,
  ThemeImportResult,
  ThemeExportResult,
  ThemeGalleryResult,
  ThemeGalleryImageResult,
  PermissionRule,
  PermissionRulesScope,
  PermissionRulesGetResult,
  PermissionRulesSetResult,
  PermissionRulesImportResult,
  PermissionRulesExportResult,
  PermissionRulesWorkspaceStatus,
  PermissionRulesRemoveResult,
  PendingPromptCounts,
  WorkspaceActivityMap,
  WorkflowRunSummary,
  WorkflowRunDetail,
  WorkflowControlAction,
  WorkflowControlResult,
  SessionRuntimeInfo,
  SessionRuntimeCloseResult,
  SessionLaunchTaskOptions,
  WorkspaceActivationIntent,
  GitConveyorStatus,
  GitConveyorCommitOptions,
  GitConveyorPullRequestOptions,
  GitConveyorPullRequestResult,
} from './ipc-contracts'
import type { ThemeFile } from './theme/theme-file'

// ─── HTTP Bridge Client ─────────────────────────────────────────────────────

const BASE = '' // relative to the web server root
const WS_BASE = '' // relative to the web server origin

/**
 * Create an HTTP/WS bridge client. Call `connect()` to establish the
 * WebSocket connection for event subscriptions.
 */
export function createHttpBridge(): PiDesktopAPI {
  const subscriptions = new Map<string, Array<(...args: unknown[]) => void>>()

  // ── Helper: HTTP POST to /api/<channel> ────────────────────────────────
  async function invoke(channel: string, ...args: unknown[]): Promise<unknown> {
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
    subscriptions.set(channel, [...(subscriptions.get(channel) || []), { ws, handler }])
    return () => {
      const subs = subscriptions.get(channel)
      if (subs) {
        const idx = subs.findIndex((s) => s.handler === handler)
        if (idx >= 0) subs.splice(idx, 1)
        ws.close()
      }
    }
  }

  // ── Pi process lifecycle ───────────────────────────────────────────────
  const pi = {
    start: (options) => invoke('pi:start', options) as Promise<PiStatus>,
    stop: () => invoke('pi:stop') as Promise<PiStatus>,
    restart: (options) => invoke('pi:restart', options) as Promise<PiStatus>,
    getStatus: () => invoke('pi:status') as Promise<PiStatus>,
    detectInstallations: (options) => invoke('pi:detect-installations', options) as Promise<AgentInstallationsResult>,
  }

  // ── Pi commands ────────────────────────────────────────────────────────
  const commands = {
    prompt: (message, options) => invoke('pi:prompt', message, options),
    steer: (message, images) => invoke('pi:steer', message, images),
    followUp: (message) => invoke('pi:follow-up', message),
    abort: () => invoke('pi:abort'),
    bash: (command) => invoke('pi:bash', command),
    abortBash: () => invoke('pi:abort-bash'),
  }

  // ── Session management ─────────────────────────────────────────────────
  const session = {
    createNew: () => invoke('session:new'),
    launchTask: (options) => invoke('session:launch-task', options),
    closeRuntime: (runtimeId) => invoke('session:close-runtime', runtimeId),
    switch: (sessionPath, cwd) => invoke('session:switch', sessionPath, cwd),
    listRuntimes: () => invoke('session:list-runtimes'),
    fork: (entryId) => invoke('session:fork', entryId),
    clone: () => invoke('session:clone'),
    list: (cwd) => invoke('session:list', cwd),
    listAll: (cwd) => invoke('session:list-all', cwd),
    getState: () => invoke('session:get-state'),
    getMessages: () => invoke('session:get-messages'),
    getStats: () => invoke('session:get-stats'),
    setName: (name) => invoke('session:set-name', name),
    exportHtml: (outputPath) => invoke('session:export-html', outputPath),
    getForkMessages: () => invoke('session:get-fork-messages'),
    delete: (sessionPath) => invoke('session:delete', sessionPath),
    archive: (sessionId) => invoke('session:archive', sessionId),
    unarchive: (sessionId) => invoke('session:unarchive', sessionId),
    listArchived: () => invoke('session:list-archived'),
    getLineage: () => invoke('session:get-lineage'),
    compact: (customInstructions) => invoke('session:compact', customInstructions),
  }

  // ── Model management ───────────────────────────────────────────────────
  const model = {
    set: (provider, modelId) => invoke('model:set', provider, modelId),
    cycle: () => invoke('model:cycle'),
    listAvailable: () => invoke('model:list-available'),
  }

  // ── Thinking ───────────────────────────────────────────────────────────
  const thinking = {
    setLevel: (level) => invoke('thinking:set-level', level),
    cycleLevel: () => invoke('thinking:cycle-level'),
  }

  // ── Settings ───────────────────────────────────────────────────────────
  const settings = {
    getAll: () => invoke('settings:get-all'),
    save: (settings) => invoke('settings:save', settings),
  }

  // ── Permission rules ───────────────────────────────────────────────────
  const permissionRules = {
    get: (scope) => invoke('permission-rules:get', scope),
    set: (scope, rules) => invoke('permission-rules:set', scope, rules),
    importFromFile: () => invoke('permission-rules:import'),
    exportToFile: (rules) => invoke('permission-rules:export', rules),
    workspaceStatus: () => invoke('permission-rules:workspace-status'),
    removeWorkspace: () => invoke('permission-rules:remove-workspace'),
    setWorkspaceTrust: (trusted) => invoke('permission-rules:set-workspace-trust', trusted),
  }

  // ── Themes ─────────────────────────────────────────────────────────────
  const themes = {
    list: () => invoke('themes:list'),
    save: (file, existingId) => invoke('themes:save', file, existingId),
    delete: (id) => invoke('themes:delete', id),
    installFromUrl: (url) => invoke('themes:install-from-url', url),
    export: (file) => invoke('themes:export', file),
    import: () => invoke('themes:import'),
    gallery: () => invoke('themes:gallery-list'),
    galleryImage: (url) => invoke('themes:gallery-image', url),
  }

  // ── Workspace management ───────────────────────────────────────────────
  const workspace = {
    list: () => invoke('workspace:list'),
    create: (name, path) => invoke('workspace:create', name, path),
    remove: (workspaceId) => invoke('workspace:remove', workspaceId),
    rename: (workspaceId, name) => invoke('workspace:rename', workspaceId, name),
    changePath: (workspaceId, newPath) => invoke('workspace:change-path', workspaceId, newPath),
    pathExists: () => invoke('workspace:path-exists'),
    setActive: (workspaceId) => invoke('workspace:set-active', workspaceId),
    getActive: () => invoke('workspace:get-active'),
    startPi: (workspaceId, options) => invoke('workspace:start-pi', workspaceId, options),
    stopPi: (workspaceId) => invoke('workspace:stop-pi', workspaceId),
    createTab: (options) => invoke('workspace:create-tab', options),
    getActivity: () => invoke('workspace:activity'),
    takePendingActivation: () => invoke('workspace:take-pending-activation'),
  }

  // ── Package management ─────────────────────────────────────────────────
  const packages = {
    listInstalled: () => invoke('package:list-installed'),
    install: (spec) => invoke('package:install', spec),
    remove: (spec) => invoke('package:remove', spec),
    update: (spec) => invoke('package:update', spec),
    fetchCatalog: (query) => invoke('package:catalog-fetch', query),
  }

  // ── Models config ──────────────────────────────────────────────────────
  const models = {
    read: () => invoke('models:read'),
    write: (config) => invoke('models:write', config),
  }

  // ── Council ────────────────────────────────────────────────────────────
  const council = {
    detect: () => invoke('council:detect'),
    runConsultants: (payload) => invoke('council:run-consultants', payload),
    arbiter: (payload) => invoke('council:arbiter', payload),
    onProgress: (callback) => subscribe('event:council-progress', callback as (...args: unknown[]) => void),
  }

  // ── Skills, Commands, MCP, Tags ────────────────────────────────────────
  const skills = { list: () => invoke('skills:list') }
  const piCommands = { list: () => invoke('commands:list') }
  const mcpServers = { list: () => invoke('mcp:servers-list') }
  const tags = {
    get: (sessionId) => invoke('tag:get', sessionId),
    set: (sessionId, tags) => invoke('tag:set', sessionId, tags),
    add: (sessionId, tag) => invoke('tag:add', sessionId, tag),
    remove: (sessionId, tag) => invoke('tag:remove', sessionId, tag),
    getAll: () => invoke('tag:get-all'),
    getAllUsed: () => invoke('tag:get-all-used'),
    autoGetAll: () => invoke('tag:auto-get-all'),
    autoEnsure: (sessions) => invoke('tag:auto-ensure', sessions),
    autoRemove: (sessionId) => invoke('tag:auto-remove', sessionId),
  }

  // ── Git conveyor ───────────────────────────────────────────────────────
  const git = {
    status: () => invoke('git:conveyor-status'),
    commit: (options) => invoke('git:conveyor-commit', options),
    push: () => invoke('git:conveyor-push'),
    createPullRequest: (options) => invoke('git:conveyor-create-pr', options),
  }

  // ── Notes ──────────────────────────────────────────────────────────────
  const notes = {
    list: () => invoke('notes:list'),
    create: (input) => invoke('notes:create', input),
    update: (id, patch) => invoke('notes:update', id, patch),
    remove: (id) => invoke('notes:remove', id),
  }

  // ── File operations ────────────────────────────────────────────────────
  const files = {
    getTree: (maxDepth) => invoke('file:tree', maxDepth),
    search: (query) => invoke('file:search', query),
    searchContent: (query) => invoke('file:search-content', query),
    read: (path) => invoke('file:read', path),
    readAttachment: (path) => invoke('file:read-attachment', path),
    write: (path, content) => invoke('file:write', path, content),
    getDiff: (filePath) => invoke('file:diff', filePath),
    getStagedDiff: (filePath) => invoke('file:staged-diff', filePath),
    getGitStatus: () => invoke('git:status'),
    getGitBranch: () => invoke('git:branch'),
  }

  // ── System ─────────────────────────────────────────────────────────────
  const system = {
    openDialog: (options) => invoke('system:open-dialog', options),
    getPath: (name) => invoke('system:get-path', name),
    getPathForFile: (_file) => '', // NOT PORTABLE: requires webUtils.getPathForFile
    pathKind: (path) => invoke('system:path-kind', path),
    openExternal: (url) => invoke('system:open-external', url),
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
    getRun: (workspaceId, runId) => invoke('workflow:get-run', workspaceId, runId),
    control: (workspaceId, runId, action) => invoke('workflow:control', workspaceId, runId, action),
    setPersistAgentSessions: (enabled) => invoke('workflow:set-persistence', enabled),
  }

  // ── Diagnostics ────────────────────────────────────────────────────────
  const diagnostics = {
    get: () => invoke('diagnostics:get'),
  }

  // ── Update check ───────────────────────────────────────────────────────
  const updates = {
    check: () => invoke('update:check'),
  }

  // ── Terminal ───────────────────────────────────────────────────────────
  const terminal = {
    start: (options) => invoke('terminal:start', options),
    input: (data) => invoke('terminal:input', data),
    resize: (cols, rows) => invoke('terminal:resize', { cols, rows }),
    stop: () => invoke('terminal:stop'),
    onData: (callback) => subscribe('event:terminal-data', callback as (...args: unknown[]) => void),
    onExit: (callback) => subscribe('event:terminal-exit', callback as (...args: unknown[]) => void),
  }

  // ── Extension UI responses ─────────────────────────────────────────────
  const ui = {
    respondSelect: (id, value) => invoke('ui:select-response', id, value),
    respondConfirm: (id, confirmed) => invoke('ui:confirm-response', id, confirmed),
    respondInput: (id, value) => invoke('ui:input-response', id, value),
    respondEditor: (id, value) => invoke('ui:editor-response', id, value),
    flushPendingPrompts: (workspaceId) => invoke('ui:pending-flush', workspaceId),
    getPendingPrompts: () => invoke('ui:pending-get'),
    setEditorDirty: (_dirty, _fileName) => {
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
    diagnostics, updates, terminal, ui,
    onEvent, onPendingPrompts, onWorkspaceActivity, onSessionRuntime,
    onActivateWorkspace, onFileChange, onMenuAction,
  }
}

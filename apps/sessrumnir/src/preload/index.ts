/**
 * Preload bridge — exposes `window.piDesktop` to the renderer.
 *
 * Transport detection:
 *   - Electron IPC when running inside Electron (contextBridge + ipcRenderer)
 *   - HTTP/WS when served by the web shell (createHttpBridge)
 *
 * The renderer always calls `window.piDesktop.<method>()` — it never knows
 * which transport is active.
 */

import { contextBridge, ipcRenderer, webUtils } from 'electron'
import type { PiDesktopAPI } from '../shared/bridge'
import { createHttpBridge } from '../shared/bridge-http'
import type {
  PiRpcEvent,
  PiStartOptions,
  FileChangeEvent,
  TerminalExitEvent,
  CouncilProgressEvent,
  PendingPromptCounts,
  WorkspaceActivityMap,
  SessionRuntimeInfo,
  WorkspaceActivationIntent,
} from '../shared/ipc-contracts'
import { IPC_CHANNELS } from '../shared/ipc-contracts'

// ─── Transport detection ────────────────────────────────────────────────────

/**
 * Returns true when running inside Electron (contextBridge + ipcRenderer
 * are available). Returns false when served by the web shell (Bun.serve).
 */
const IS_ELECTRON = typeof contextBridge !== 'undefined' && typeof ipcRenderer !== 'undefined'

// ─── Bridge factory ─────────────────────────────────────────────────────────

/**
 * Create the bridge implementation based on the detected transport.
 * The renderer always calls `window.piDesktop` — it never knows which
 * transport is active.
 */
function createBridge(): PiDesktopAPI {
  if (IS_ELECTRON) {
    // ── Electron IPC bridge ──────────────────────────────────────────────
    const api: PiDesktopAPI = {
      pi: {
        start: (options?: PiStartOptions) => ipcRenderer.invoke(IPC_CHANNELS.PI_START, options),
        stop: () => ipcRenderer.invoke(IPC_CHANNELS.PI_STOP),
        restart: (options?: PiStartOptions) => ipcRenderer.invoke(IPC_CHANNELS.PI_RESTART, options),
        getStatus: () => ipcRenderer.invoke(IPC_CHANNELS.PI_STATUS),
        detectInstallations: (options) => ipcRenderer.invoke(IPC_CHANNELS.PI_DETECT_INSTALLATIONS, options),
      },

      commands: {
        prompt: (message, options) => ipcRenderer.invoke(IPC_CHANNELS.PI_PROMPT, message, options),
        steer: (message, images) => ipcRenderer.invoke(IPC_CHANNELS.PI_STEER, message, images),
        followUp: (message) => ipcRenderer.invoke(IPC_CHANNELS.PI_FOLLOW_UP, message),
        abort: () => ipcRenderer.invoke(IPC_CHANNELS.PI_ABORT),
        bash: (command) => ipcRenderer.invoke(IPC_CHANNELS.PI_BASH, command),
        abortBash: () => ipcRenderer.invoke(IPC_CHANNELS.PI_ABORT_BASH),
      },

      session: {
        createNew: () => ipcRenderer.invoke(IPC_CHANNELS.SESSION_NEW),
        launchTask: (options) => ipcRenderer.invoke(IPC_CHANNELS.SESSION_LAUNCH_TASK, options),
        closeRuntime: (runtimeId) => ipcRenderer.invoke(IPC_CHANNELS.SESSION_CLOSE_RUNTIME, runtimeId),
        switch: (sessionPath, cwd) => ipcRenderer.invoke(IPC_CHANNELS.SESSION_SWITCH, sessionPath, cwd),
        listRuntimes: () => ipcRenderer.invoke(IPC_CHANNELS.SESSION_LIST_RUNTIMES),
        fork: (entryId) => ipcRenderer.invoke(IPC_CHANNELS.SESSION_FORK, entryId),
        clone: () => ipcRenderer.invoke(IPC_CHANNELS.SESSION_CLONE),
        list: (cwd) => ipcRenderer.invoke(IPC_CHANNELS.SESSION_LIST, cwd),
        listAll: (cwd) => ipcRenderer.invoke(IPC_CHANNELS.SESSION_LIST_ALL, cwd),
        getState: () => ipcRenderer.invoke(IPC_CHANNELS.SESSION_GET_STATE),
        getMessages: () => ipcRenderer.invoke(IPC_CHANNELS.SESSION_GET_MESSAGES),
        getStats: () => ipcRenderer.invoke(IPC_CHANNELS.SESSION_GET_STATS),
        setName: (name) => ipcRenderer.invoke(IPC_CHANNELS.SESSION_SET_NAME, name),
        exportHtml: (outputPath) => ipcRenderer.invoke(IPC_CHANNELS.SESSION_EXPORT_HTML, outputPath),
        getForkMessages: () => ipcRenderer.invoke(IPC_CHANNELS.SESSION_GET_FORK_MESSAGES),
        getLineage: () => ipcRenderer.invoke(IPC_CHANNELS.SESSION_GET_LINEAGE),
        compact: (customInstructions) => ipcRenderer.invoke(IPC_CHANNELS.SESSION_COMPACT, customInstructions),
        delete: (sessionPath) => ipcRenderer.invoke(IPC_CHANNELS.SESSION_DELETE, sessionPath),
        archive: (sessionId) => ipcRenderer.invoke(IPC_CHANNELS.SESSION_ARCHIVE, sessionId),
        unarchive: (sessionId) => ipcRenderer.invoke(IPC_CHANNELS.SESSION_UNARCHIVE, sessionId),
        listArchived: () => ipcRenderer.invoke(IPC_CHANNELS.SESSION_LIST_ARCHIVED),
      },

      model: {
        set: (provider, modelId) => ipcRenderer.invoke(IPC_CHANNELS.MODEL_SET, provider, modelId),
        cycle: () => ipcRenderer.invoke(IPC_CHANNELS.MODEL_CYCLE),
        listAvailable: () => ipcRenderer.invoke(IPC_CHANNELS.MODEL_LIST_AVAILABLE),
      },

      thinking: {
        setLevel: (level) => ipcRenderer.invoke(IPC_CHANNELS.THINKING_SET_LEVEL, level),
        cycleLevel: () => ipcRenderer.invoke(IPC_CHANNELS.THINKING_CYCLE_LEVEL),
      },

      settings: {
        getAll: () => ipcRenderer.invoke(IPC_CHANNELS.SETTINGS_GET_ALL),
        save: (settings) => ipcRenderer.invoke(IPC_CHANNELS.SETTINGS_SAVE, settings),
      },

      permissionRules: {
        get: (scope) => ipcRenderer.invoke(IPC_CHANNELS.PERMISSION_RULES_GET, scope),
        set: (scope, rules) => ipcRenderer.invoke(IPC_CHANNELS.PERMISSION_RULES_SET, scope, rules),
        importFromFile: () => ipcRenderer.invoke(IPC_CHANNELS.PERMISSION_RULES_IMPORT),
        exportToFile: (rules) => ipcRenderer.invoke(IPC_CHANNELS.PERMISSION_RULES_EXPORT, rules),
        workspaceStatus: () => ipcRenderer.invoke(IPC_CHANNELS.PERMISSION_RULES_WORKSPACE_STATUS),
        removeWorkspace: () => ipcRenderer.invoke(IPC_CHANNELS.PERMISSION_RULES_REMOVE_WORKSPACE),
        setWorkspaceTrust: (trusted) => ipcRenderer.invoke(IPC_CHANNELS.PERMISSION_RULES_SET_WORKSPACE_TRUST, trusted),
      },

      themes: {
        list: () => ipcRenderer.invoke(IPC_CHANNELS.THEMES_LIST),
        save: (file, existingId) => ipcRenderer.invoke(IPC_CHANNELS.THEMES_SAVE, file, existingId),
        delete: (id) => ipcRenderer.invoke(IPC_CHANNELS.THEMES_DELETE, id),
        installFromUrl: (url) => ipcRenderer.invoke(IPC_CHANNELS.THEMES_INSTALL_URL, url),
        export: (file) => ipcRenderer.invoke(IPC_CHANNELS.THEMES_EXPORT, file),
        import: () => ipcRenderer.invoke(IPC_CHANNELS.THEMES_IMPORT),
        gallery: () => ipcRenderer.invoke(IPC_CHANNELS.THEMES_GALLERY_LIST),
        galleryImage: (url) => ipcRenderer.invoke(IPC_CHANNELS.THEMES_GALLERY_IMAGE, url),
      },

      workspace: {
        list: () => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_LIST),
        create: (name, path) => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_CREATE, name, path),
        remove: (workspaceId) => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_REMOVE, workspaceId),
        rename: (workspaceId, name) => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_RENAME, workspaceId, name),
        changePath: (workspaceId, newPath) => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_CHANGE_PATH, workspaceId, newPath),
        pathExists: () => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_PATH_EXISTS),
        setActive: (workspaceId) => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_SET_ACTIVE, workspaceId),
        getActive: () => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_GET_ACTIVE),
        startPi: (workspaceId, options) => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_START_PI, workspaceId, options),
        stopPi: (workspaceId) => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_STOP_PI, workspaceId),
        createTab: (options) => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_CREATE_TAB, options),
        getActivity: () => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_ACTIVITY_GET),
        takePendingActivation: () => ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_TAKE_PENDING_ACTIVATION),
      },

      packages: {
        listInstalled: () => ipcRenderer.invoke(IPC_CHANNELS.PACKAGE_LIST_INSTALLED),
        install: (spec) => ipcRenderer.invoke(IPC_CHANNELS.PACKAGE_INSTALL, spec),
        remove: (spec) => ipcRenderer.invoke(IPC_CHANNELS.PACKAGE_REMOVE, spec),
        update: (spec) => ipcRenderer.invoke(IPC_CHANNELS.PACKAGE_UPDATE, spec),
        updateAll: () => ipcRenderer.invoke(IPC_CHANNELS.PACKAGE_UPDATE_ALL),
        checkUpdates: () => ipcRenderer.invoke(IPC_CHANNELS.PACKAGE_CHECK_UPDATES),
        fetchCatalog: (query) => ipcRenderer.invoke(IPC_CHANNELS.PACKAGE_CATALOG_FETCH, query),
      },

      models: {
        read: () => ipcRenderer.invoke(IPC_CHANNELS.MODELS_READ),
        write: (config) => ipcRenderer.invoke(IPC_CHANNELS.MODELS_WRITE, config),
      },

      council: {
        detect: () => ipcRenderer.invoke(IPC_CHANNELS.COUNCIL_DETECT),
        runConsultants: (payload) => ipcRenderer.invoke(IPC_CHANNELS.COUNCIL_RUN_CONSULTANTS, payload),
        arbiter: (payload) => ipcRenderer.invoke(IPC_CHANNELS.COUNCIL_ARBITER, payload),
        onProgress: (callback) => {
          const handler = (_event: Electron.IpcRendererEvent, data: CouncilProgressEvent) => callback(data)
          ipcRenderer.on(IPC_CHANNELS.EVENT_COUNCIL_PROGRESS, handler)
          return () => ipcRenderer.removeListener(IPC_CHANNELS.EVENT_COUNCIL_PROGRESS, handler)
        },
      },

      skills: {
        list: () => ipcRenderer.invoke(IPC_CHANNELS.SKILLS_LIST),
      },
      piCommands: {
        list: () => ipcRenderer.invoke(IPC_CHANNELS.COMMANDS_LIST),
      },
      mcpServers: {
        list: () => ipcRenderer.invoke(IPC_CHANNELS.MCP_SERVERS_LIST),
      },
      tags: {
        get: (sessionId) => ipcRenderer.invoke(IPC_CHANNELS.TAG_GET, sessionId),
        set: (sessionId, tags) => ipcRenderer.invoke(IPC_CHANNELS.TAG_SET, sessionId, tags),
        add: (sessionId, tag) => ipcRenderer.invoke(IPC_CHANNELS.TAG_ADD, sessionId, tag),
        remove: (sessionId, tag) => ipcRenderer.invoke(IPC_CHANNELS.TAG_REMOVE, sessionId, tag),
        getAll: () => ipcRenderer.invoke(IPC_CHANNELS.TAG_GET_ALL),
        getAllUsed: () => ipcRenderer.invoke(IPC_CHANNELS.TAG_GET_ALL_USED),
        autoGetAll: () => ipcRenderer.invoke(IPC_CHANNELS.TAG_AUTO_GET_ALL),
        autoEnsure: (sessions) => ipcRenderer.invoke(IPC_CHANNELS.TAG_AUTO_ENSURE, sessions),
        autoRemove: (sessionId) => ipcRenderer.invoke(IPC_CHANNELS.TAG_AUTO_REMOVE, sessionId),
      },

      git: {
        status: () => ipcRenderer.invoke(IPC_CHANNELS.GIT_CONVEYOR_STATUS),
        commit: (options) => ipcRenderer.invoke(IPC_CHANNELS.GIT_CONVEYOR_COMMIT, options),
        push: () => ipcRenderer.invoke(IPC_CHANNELS.GIT_CONVEYOR_PUSH),
        createPullRequest: (options) => ipcRenderer.invoke(IPC_CHANNELS.GIT_CONVEYOR_CREATE_PR, options),
      },

      notes: {
        list: () => ipcRenderer.invoke(IPC_CHANNELS.NOTES_LIST),
        create: (input) => ipcRenderer.invoke(IPC_CHANNELS.NOTES_CREATE, input),
        update: (id, patch) => ipcRenderer.invoke(IPC_CHANNELS.NOTES_UPDATE, id, patch),
        remove: (id) => ipcRenderer.invoke(IPC_CHANNELS.NOTES_REMOVE, id),
      },

      files: {
        getTree: (maxDepth) => ipcRenderer.invoke(IPC_CHANNELS.FILE_TREE, maxDepth),
        search: (query) => ipcRenderer.invoke(IPC_CHANNELS.FILE_SEARCH, query),
        searchContent: (query) => ipcRenderer.invoke(IPC_CHANNELS.FILE_SEARCH_CONTENT, query),
        read: (path) => ipcRenderer.invoke(IPC_CHANNELS.FILE_READ, path),
        readAttachment: (path) => ipcRenderer.invoke(IPC_CHANNELS.FILE_READ_ATTACHMENT, path),
        write: (path, content) => ipcRenderer.invoke(IPC_CHANNELS.FILE_WRITE, path, content),
        getDiff: (filePath) => ipcRenderer.invoke(IPC_CHANNELS.FILE_DIFF, filePath),
        getStagedDiff: (filePath) => ipcRenderer.invoke(IPC_CHANNELS.FILE_STAGED_DIFF, filePath),
        getGitStatus: () => ipcRenderer.invoke(IPC_CHANNELS.GIT_STATUS),
        getGitBranch: () => ipcRenderer.invoke(IPC_CHANNELS.GIT_BRANCH),
      },

      system: {
        openDialog: (options) => ipcRenderer.invoke(IPC_CHANNELS.SYSTEM_OPEN_DIALOG, options),
        getPath: (name) => ipcRenderer.invoke(IPC_CHANNELS.SYSTEM_GET_PATH, name),
        getPathForFile: (file) => webUtils.getPathForFile(file),
        pathKind: (path) => ipcRenderer.invoke(IPC_CHANNELS.SYSTEM_PATH_KIND, path),
        platform: process.platform,
        openExternal: (url) => ipcRenderer.invoke(IPC_CHANNELS.SYSTEM_OPEN_EXTERNAL, url),
        hallUrl: () => ipcRenderer.invoke(IPC_CHANNELS.SYSTEM_HALL_URL),
        getVersion: () => ipcRenderer.invoke(IPC_CHANNELS.SYSTEM_GET_VERSION),
      },

      activity: {
        getStats: () => ipcRenderer.invoke(IPC_CHANNELS.ACTIVITY_GET_STATS),
      },

      workflows: {
        list: () => ipcRenderer.invoke(IPC_CHANNELS.WORKFLOW_LIST),
        getRun: (workspaceId, runId) => ipcRenderer.invoke(IPC_CHANNELS.WORKFLOW_GET_RUN, workspaceId, runId),
        control: (workspaceId, runId, action) => ipcRenderer.invoke(IPC_CHANNELS.WORKFLOW_CONTROL, workspaceId, runId, action),
        setPersistAgentSessions: (enabled) => ipcRenderer.invoke(IPC_CHANNELS.WORKFLOW_SET_PERSISTENCE, enabled),
      },

      diagnostics: {
        get: () => ipcRenderer.invoke(IPC_CHANNELS.DIAGNOSTICS_GET),
      },

      updates: {
        check: () => ipcRenderer.invoke(IPC_CHANNELS.UPDATE_CHECK),
      },

      i18n: {
        getEnvironment: () => ipcRenderer.invoke(IPC_CHANNELS.I18N_GET_ENVIRONMENT),
      },

      terminal: {
        start: (options) => ipcRenderer.invoke(IPC_CHANNELS.TERMINAL_START, options),
        input: (data) => ipcRenderer.invoke(IPC_CHANNELS.TERMINAL_INPUT, data),
        resize: (cols, rows) => ipcRenderer.invoke(IPC_CHANNELS.TERMINAL_RESIZE, { cols, rows }),
        stop: () => ipcRenderer.invoke(IPC_CHANNELS.TERMINAL_STOP),
        onData: (callback) => {
          const handler = (_event: Electron.IpcRendererEvent, data: string) => callback(data)
          ipcRenderer.on(IPC_CHANNELS.EVENT_TERMINAL_DATA, handler)
          return () => ipcRenderer.removeListener(IPC_CHANNELS.EVENT_TERMINAL_DATA, handler)
        },
        onExit: (callback) => {
          const handler = (_event: Electron.IpcRendererEvent, data: TerminalExitEvent) => callback(data)
          ipcRenderer.on(IPC_CHANNELS.EVENT_TERMINAL_EXIT, handler)
          return () => ipcRenderer.removeListener(IPC_CHANNELS.EVENT_TERMINAL_EXIT, handler)
        },
      },

      ui: {
        respondSelect: (id, value) => ipcRenderer.invoke(IPC_CHANNELS.UI_SELECT_RESPONSE, id, value),
        respondConfirm: (id, confirmed) => ipcRenderer.invoke(IPC_CHANNELS.UI_CONFIRM_RESPONSE, id, confirmed),
        respondInput: (id, value) => ipcRenderer.invoke(IPC_CHANNELS.UI_INPUT_RESPONSE, id, value),
        respondEditor: (id, value) => ipcRenderer.invoke(IPC_CHANNELS.UI_EDITOR_RESPONSE, id, value),
        flushPendingPrompts: (workspaceId) => ipcRenderer.invoke(IPC_CHANNELS.UI_PENDING_FLUSH, workspaceId),
        getPendingPrompts: () => ipcRenderer.invoke(IPC_CHANNELS.UI_PENDING_GET),
        setEditorDirty: (dirty, fileName) =>
          ipcRenderer.send(
            IPC_CHANNELS.UI_EDITOR_DIRTY_SET,
            dirty === true,
            typeof fileName === 'string' ? fileName : null
          ),
      },

      onEvent: (callback) => {
        const handler = (_event: Electron.IpcRendererEvent, data: PiRpcEvent) => callback(data)
        ipcRenderer.on(IPC_CHANNELS.EVENT_PI, handler)
        return () => {
          ipcRenderer.removeListener(IPC_CHANNELS.EVENT_PI, handler)
        }
      },

      onPendingPrompts: (callback) => {
        const handler = (_event: Electron.IpcRendererEvent, data: PendingPromptCounts) => callback(data)
        ipcRenderer.on(IPC_CHANNELS.EVENT_PENDING_PROMPTS, handler)
        return () => {
          ipcRenderer.removeListener(IPC_CHANNELS.EVENT_PENDING_PROMPTS, handler)
        }
      },

      onWorkspaceActivity: (callback) => {
        const handler = (_event: Electron.IpcRendererEvent, data: WorkspaceActivityMap) => callback(data)
        ipcRenderer.on(IPC_CHANNELS.EVENT_WORKSPACE_ACTIVITY, handler)
        return () => {
          ipcRenderer.removeListener(IPC_CHANNELS.EVENT_WORKSPACE_ACTIVITY, handler)
        }
      },

      onSessionRuntime: (callback) => {
        const handler = (_event: Electron.IpcRendererEvent, data: SessionRuntimeInfo) => callback(data)
        ipcRenderer.on(IPC_CHANNELS.EVENT_SESSION_RUNTIME, handler)
        return () => {
          ipcRenderer.removeListener(IPC_CHANNELS.EVENT_SESSION_RUNTIME, handler)
        }
      },

      onActivateWorkspace: (callback) => {
        const handler = (_event: Electron.IpcRendererEvent, data: WorkspaceActivationIntent) => callback(data)
        ipcRenderer.on(IPC_CHANNELS.EVENT_ACTIVATE_WORKSPACE, handler)
        return () => {
          ipcRenderer.removeListener(IPC_CHANNELS.EVENT_ACTIVATE_WORKSPACE, handler)
        }
      },

      onFileChange: (callback) => {
        const handler = (_event: Electron.IpcRendererEvent, data: FileChangeEvent) => callback(data)
        ipcRenderer.on(IPC_CHANNELS.EVENT_FILE_CHANGE, handler)
        return () => {
          ipcRenderer.removeListener(IPC_CHANNELS.EVENT_FILE_CHANGE, handler)
        }
      },

      onMenuAction: (callback) => {
        const handlers: Array<() => void> = []
        const actions = ['menu:new-session', 'menu:new-workspace', 'menu:open-project']

        for (const action of actions) {
          const handler = () => callback(action)
          ipcRenderer.on(action, handler)
          handlers.push(() => ipcRenderer.removeListener(action, handler))
        }

        return () => {
          for (const cleanup of handlers) cleanup()
        }
      },
    }
    return api
  }

  // ── HTTP/WS bridge (web shell) ─────────────────────────────────────────
  return createHttpBridge()
}

// ─── Expose to Renderer ─────────────────────────────────────────────────────

const bridge = createBridge()
contextBridge.exposeInMainWorld('piDesktop', bridge)

// Re-export the type for renderer usage
export type { PiDesktopAPI }

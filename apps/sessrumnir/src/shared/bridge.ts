/**
 * Bridge interface — the single typed surface the renderer talks to.
 *
 * Both transports (Electron IPC and HTTP/WS) implement this interface.
 * The renderer never knows which transport is active; it only calls
 * `window.piDesktop.<method>()`.
 *
 * This file is the contract. The preload and the web server must both
 * satisfy it.
 */

import type {
  PiRpcEvent,
  PiStartOptions,
  PiStatus,
  SessionListItem,
  SessionDeleteResult,
  ArchivedSessionsMap,
  AppSettings,
  AgentDetectionOptions,
  AgentInstallationsResult,
  Workspace,
  WorkspaceTabOptions,
  WorkspaceRemoveResult,
  InstalledPackage,
  InstalledSkill,
  CatalogPackage,
  FileTreeNode,
  FileSearchResult,
  FileChangeEvent,
  GitFileStatus,
  TerminalExitEvent,
  TerminalStartOptions,
  TerminalStartResult,
  Note,
  NoteInput,
  NoteUpdate,
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

/**
 * The unified bridge interface. Both the Electron preload and the
 * HTTP/WS web client implement this. The renderer calls methods on
 * `window.piDesktop` which is typed as this interface.
 */
export interface PiDesktopAPI {
  // ── Pi process lifecycle ────────────────────────────────────────────────
  pi: {
    start(options?: PiStartOptions): Promise<PiStatus>
    stop(): Promise<PiStatus>
    restart(options?: PiStartOptions): Promise<PiStatus>
    getStatus(): Promise<PiStatus>
    detectInstallations(options?: AgentDetectionOptions): Promise<AgentInstallationsResult>
  }

  // ── Pi commands ─────────────────────────────────────────────────────────
  commands: {
    prompt(message: string, options?: { images?: PromptImage[]; streamingBehavior?: string }): Promise<unknown>
    steer(message: string, images?: PromptImage[]): Promise<unknown>
    followUp(message: string): Promise<unknown>
    abort(): Promise<unknown>
    bash(command: string): Promise<unknown>
    abortBash(): Promise<unknown>
  }

  // ── Session management ──────────────────────────────────────────────────
  session: {
    createNew(): Promise<SessionRuntimeInfo>
    launchTask(options: SessionLaunchTaskOptions): Promise<SessionRuntimeInfo>
    closeRuntime(runtimeId: string): Promise<SessionRuntimeCloseResult | null>
    switch(sessionPath: string, cwd?: string): Promise<SessionRuntimeInfo>
    listRuntimes(): Promise<SessionRuntimeInfo[]>
    fork(entryId?: string): Promise<unknown>
    clone(): Promise<unknown>
    list(cwd?: string): Promise<SessionListItem[]>
    listAll(cwd?: string): Promise<SessionListItem[]>
    getState(): Promise<unknown>
    getMessages(): Promise<unknown>
    getStats(): Promise<unknown>
    setName(name: string): Promise<unknown>
    exportHtml(outputPath?: string): Promise<unknown>
    getForkMessages(): Promise<unknown>
    delete(sessionPath: string): Promise<SessionDeleteResult>
    archive(sessionId: string): Promise<ArchivedSessionsMap>
    unarchive(sessionId: string): Promise<ArchivedSessionsMap>
    listArchived(): Promise<ArchivedSessionsMap>
    getLineage(): Promise<SessionLineageRecord[]>
    compact(customInstructions?: string): Promise<unknown>
  }

  // ── Model management ────────────────────────────────────────────────────
  model: {
    set(provider: string, modelId: string): Promise<unknown>
    cycle(): Promise<unknown>
    listAvailable(): Promise<unknown>
  }

  // ── Thinking ────────────────────────────────────────────────────────────
  thinking: {
    setLevel(level: string): Promise<unknown>
    cycleLevel(): Promise<unknown>
  }

  // ── Settings ────────────────────────────────────────────────────────────
  settings: {
    getAll(): Promise<AppSettings>
    save(settings: Partial<AppSettings>): Promise<AppSettings>
  }

  // ── Permission rules ────────────────────────────────────────────────────
  permissionRules: {
    get(scope: PermissionRulesScope): Promise<PermissionRulesGetResult>
    set(scope: PermissionRulesScope, rules: PermissionRule[]): Promise<PermissionRulesSetResult>
    importFromFile(): Promise<PermissionRulesImportResult>
    exportToFile(rules: PermissionRule[]): Promise<PermissionRulesExportResult>
    workspaceStatus(): Promise<PermissionRulesWorkspaceStatus>
    removeWorkspace(): Promise<PermissionRulesRemoveResult>
    setWorkspaceTrust(trusted: boolean): Promise<PermissionRulesWorkspaceStatus>
  }

  // ── Themes ──────────────────────────────────────────────────────────────
  themes: {
    list(): Promise<ThemesListResult>
    save(file: ThemeFile, existingId?: string): Promise<{ id: string }>
    delete(id: string): Promise<void>
    installFromUrl(url: string): Promise<ThemeImportResult>
    export(file: ThemeFile): Promise<ThemeExportResult>
    import(): Promise<ThemeImportResult>
    gallery(): Promise<ThemeGalleryResult>
    galleryImage(url: string): Promise<ThemeGalleryImageResult>
  }

  // ── Workspace management ────────────────────────────────────────────────
  workspace: {
    list(): Promise<Workspace[]>
    create(name: string, path: string): Promise<Workspace>
    createTab(options?: WorkspaceTabOptions): Promise<Workspace>
    remove(workspaceId: string): Promise<WorkspaceRemoveResult>
    rename(workspaceId: string, name: string): Promise<void>
    changePath(workspaceId: string, newPath: string): Promise<void>
    pathExists(): Promise<boolean>
    setActive(workspaceId: string): Promise<Workspace>
    getActive(): Promise<Workspace | null>
    startPi(workspaceId: string, options?: PiStartOptions): Promise<PiStatus>
    stopPi(workspaceId: string): Promise<PiStatus>
    getActivity(): Promise<WorkspaceActivityMap>
    takePendingActivation(): Promise<WorkspaceActivationIntent | null>
  }

  // ── Package management ──────────────────────────────────────────────────
  packages: {
    listInstalled(): Promise<InstalledPackage[]>
    install(spec: string): Promise<{ success: boolean; output: string }>
    remove(spec: string): Promise<{ success: boolean; output: string }>
    update(spec?: string): Promise<{ success: boolean; output: string }>
    fetchCatalog(query?: string): Promise<CatalogPackage[]>
  }

  // ── Models config ───────────────────────────────────────────────────────
  models: {
    read(): Promise<ModelsReadResult>
    write(config: ModelsConfig): Promise<{ success: boolean; error?: string }>
  }

  // ── Council ─────────────────────────────────────────────────────────────
  council: {
    detect(): Promise<CouncilDetectResult>
    runConsultants(payload: CouncilRunRequest): Promise<CouncilRunResult>
    arbiter(payload: CouncilArbiterRequest): Promise<CouncilArbiterResult>
    onProgress(callback: (event: CouncilProgressEvent) => void): () => void
  }

  // ── Skills, Commands, MCP, Tags ─────────────────────────────────────────
  skills: { list(): Promise<InstalledSkill[]> }
  piCommands: { list(): Promise<unknown[]> }
  mcpServers: { list(): Promise<unknown[]> }
  tags: {
    get(sessionId: string): Promise<string[]>
    set(sessionId: string, tags: string[]): Promise<string[]>
    add(sessionId: string, tag: string): Promise<string[]>
    remove(sessionId: string, tag: string): Promise<string[]>
    getAll(): Promise<Record<string, string[]>>
    getAllUsed(): Promise<string[]>
    autoGetAll(): Promise<Record<string, string>>
    autoEnsure(sessions: Array<{ sessionId: string; path: string }>): Promise<Record<string, string>>
    autoRemove(sessionId: string): Promise<void>
  }

  // ── Git conveyor ────────────────────────────────────────────────────────
  git: {
    status(): Promise<GitConveyorStatus>
    commit(options: GitConveyorCommitOptions): Promise<GitConveyorStatus>
    push(): Promise<GitConveyorStatus>
    createPullRequest(options: GitConveyorPullRequestOptions): Promise<GitConveyorPullRequestResult>
  }

  // ── Notes ───────────────────────────────────────────────────────────────
  notes: {
    list(): Promise<Note[]>
    create(input: NoteInput): Promise<Note>
    update(id: string, patch: NoteUpdate): Promise<Note>
    remove(id: string): Promise<void>
  }

  // ── File operations ─────────────────────────────────────────────────────
  files: {
    getTree(maxDepth?: number): Promise<FileTreeNode>
    search(query: string): Promise<FileSearchResult[]>
    searchContent(query: string): Promise<FileSearchResult[]>
    read(path: string): Promise<string>
    readAttachment(path: string): Promise<AttachmentReadResult>
    write(path: string, content: string): Promise<{ ok: boolean }>
    getDiff(filePath?: string): Promise<string>
    getStagedDiff(filePath?: string): Promise<string>
    getGitStatus(): Promise<Record<string, GitFileStatus>>
    getGitBranch(): Promise<string | null>
  }

  // ── System ──────────────────────────────────────────────────────────────
  system: {
    openDialog(options?: OpenDialogOptions): Promise<string | null>
    getPath(name: string): Promise<string>
    getPathForFile(file: File): string
    pathKind(path: string): Promise<PathKindResult>
    openExternal(url: string): Promise<void>
    hallUrl(): Promise<string>
    getVersion(): Promise<string>
    platform: NodeJS.Platform
  }

  // ── Activity stats ──────────────────────────────────────────────────────
  activity: {
    getStats(): Promise<ActivityStatsResult>
  }

  // ── Workflow run monitoring ─────────────────────────────────────────────
  workflows: {
    list(): Promise<WorkflowRunSummary[]>
    getRun(workspaceId: string, runId: string): Promise<WorkflowRunDetail>
    control(workspaceId: string, runId: string, action: WorkflowControlAction): Promise<WorkflowControlResult>
    setPersistAgentSessions(enabled: boolean): Promise<void>
  }

  // ── Diagnostics ─────────────────────────────────────────────────────────
  diagnostics: {
    get(): Promise<DiagnosticsReport>
  }

  // ── Update check ────────────────────────────────────────────────────────
  updates: {
    check(): Promise<UpdateCheckResult>
  }

  // ── Terminal ────────────────────────────────────────────────────────────
  terminal: {
    start(options?: TerminalStartOptions): Promise<TerminalStartResult>
    input(data: string): Promise<void>
    resize(cols: number, rows: number): Promise<void>
    stop(): Promise<void>
    onData(callback: (data: string) => void): () => void
    onExit(callback: (event: TerminalExitEvent) => void): () => void
  }

  // ── Extension UI responses ──────────────────────────────────────────────
  ui: {
    respondSelect(id: string, value: string): void
    respondConfirm(id: string, confirmed: boolean): void
    respondInput(id: string, value: string): void
    respondEditor(id: string, value: string): void
    flushPendingPrompts(workspaceId: string): Promise<void>
    getPendingPrompts(): Promise<PendingPromptCounts>
    setEditorDirty(dirty: boolean, fileName: string | null): void
  }

  // ── Event subscriptions ─────────────────────────────────────────────────
  onEvent(callback: (event: PiRpcEvent) => void): () => void
  onPendingPrompts(callback: (counts: PendingPromptCounts) => void): () => void
  onWorkspaceActivity(callback: (map: WorkspaceActivityMap) => void): () => void
  onSessionRuntime(callback: (runtime: SessionRuntimeInfo) => void): () => void
  onActivateWorkspace(callback: (payload: WorkspaceActivationIntent) => void): () => void
  onFileChange(callback: (event: FileChangeEvent) => void): () => void
  onMenuAction(callback: (action: string) => void): () => void
}

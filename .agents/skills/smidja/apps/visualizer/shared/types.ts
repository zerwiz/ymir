/**
 * Types shared by the read-only server and the Vue client.
 *
 * Every interface mirrors a table in factory.db one-for-one (see
 * references/observability.md). Nothing here is derived state: phase durations,
 * session progress and lane layout are computed in the UI, never stored.
 */

/** sessions.status — a run is running until it earns success. */
export type SessionStatus = "running" | "success" | "fail";

/** phases.status — queued only for manifest-declared phases not yet entered. */
export type PhaseStatus = "queued" | "running" | "success" | "fail";

/** phases.kind — decides which lane a block renders in. */
export type PhaseKind = "engineer" | "code" | "agent";

/** events.type — the ten types tracer.py emits. */
export type EventType =
  | "phase_start"
  | "phase_end"
  | "agent_start"
  | "agent_end"
  | "tool_call"
  | "handoff"
  | "gate_pass"
  | "gate_fail"
  | "log"
  | "error"
  | "agent_output"
  | "usage";

export interface Session {
  factory_id: string;
  /** factory script(s) that ran this session, e.g. "factory_plan + factory_build_test". */
  factory_name: string | null;
  request: string | null;
  status: SessionStatus | null;
  engineer: string | null;
  started_at: string | null;
  ended_at: string | null;
  total_tokens: number | null;
  total_cost: number | null;
  /** 1 once archived out of the review list. Review state, not run state. */
  archived: number | null;
}

/**
 * A session row with its phases embedded, so the L1 table draws the
 * mini-progress dots without a second request per row.
 */
export interface SessionSummary extends Session {
  /** Full phase rows, ordered by seq — one dot each. */
  phases: Phase[];
  phase_count: number;
  /**
   * The session's agents, same shape and merge rules as SessionDetail.agents —
   * so an L1 card can color its per-agent dots without a request per card.
   */
  agents: AgentSession[];
  /** Derived from the session's first agent — used by the chat sidebar's past list. */
  model: string | null;
}

export interface Phase {
  phase_id: string;
  factory_id: string;
  seq: number | null;
  name: string | null;
  kind: PhaseKind | null;
  owner: string | null;
  description: string | null;
  status: PhaseStatus | null;
  attempt: number | null;
  retries: number | null;
  error: string | null;
  started_at: string | null;
  ended_at: string | null;
}

export interface Event {
  /** SQLite rowid — the polling cursor. Monotonic, insertion-ordered. */
  rowid: number;
  event_id: string;
  factory_id: string;
  phase_id: string | null;
  /** Span nesting: an agent phase expands into its tool-call children. */
  parent_id: string | null;
  type: EventType | null;
  name: string | null;
  /** Raw JSON string as written by the tracer; parse at the point of display. */
  payload_json: string | null;
  tokens: number | null;
  started_at: string | null;
  ended_at: string | null;
}

export interface Envelope {
  envelope_id: string;
  factory_id: string;
  phase_id: string | null;
  agent: string | null;
  /** Name of the data_types model the response was parsed against. */
  output_type: string | null;
  payload_json: string | null;
  /** SQLite integer boolean. */
  valid: number | null;
  attempt: number | null;
  created_at: string | null;
}

export interface GateResult {
  id: number;
  factory_id: string;
  phase_id: string | null;
  attempt: number | null;
  gate: string | null;
  /** SQLite integer boolean. */
  passed: number | null;
  /** JSON array of violation strings; "[]" on a pass. */
  violations_json: string | null;
  /**
   * JSON array of GateCheck — the per-item evidence behind the verdict, so a
   * green gate can say WHAT it verified rather than only that it passed.
   * Null on rows written before the tracer recorded checks; those are not
   * backfilled, so fall back to the verdict alone.
   */
  checks_json: string | null;
  created_at: string | null;
}

/** One item a gate inspected — the parsed element of `checks_json`. */
export interface GateCheck {
  item: string;
  ok: boolean;
  note: string;
}

/** agent_sessions — the queryable mirror of agent_map.json. Supplies lane labels (`name · model`). */
export interface AgentSession {
  factory_id: string;
  agent: string;
  coding_agent: string | null;
  model: string | null;
  session_id: string | null;
  /**
   * The agent's lane color from factory.config.yaml, e.g. "#a78bfa". Null on dbs
   * written by a tracer predating the column, and on agents with no configured
   * color — fall back to the UI's own palette.
   */
  color: string | null;
  /**
   * How full the agent's context window was after its last turn, and the
   * model's ceiling. Null on dbs predating the columns and on an agent still
   * running — the lane draws no bar rather than a misleading empty one.
   */
  context_tokens: number | null;
  context_window: number | null;
  created_at: string | null;
  last_used_at: string | null;
}

// ── payload_json shapes ──────────────────────────────────────────────────────
// events.payload_json is stored as a string. These are the parsed shapes for
// the two payloads the UI renders; every field is optional because the tracer
// writes what the coding agent reported, which varies by agent and by version.

/** Parsed `agent_start` payload — the live source of a lane's label and color. */
export interface AgentStartPayload {
  model?: string;
  thinking?: string;
  session_id?: string;
  color?: string;
  coding_agent?: string;
  purpose?: string;
  /** Tool allowlist; null means all tools. Absent on pre-config-payload rows. */
  tools?: string[] | null;
  harness_engineering?: string[];
}

/**
 * Tokens and dollars per component for one agent phase, summed across every
 * send it made (a retried phase paid more than once). Mirrors pi's `usage`:
 * `input_tokens` EXCLUDES cache reads, which bill at their own rate.
 */
export interface UsageBreakdown {
  input_tokens: number;
  output_tokens: number;
  cache_read_tokens: number;
  cache_write_tokens: number;
  /**
   * Thinking tokens — the reasoning SHARE of `output_tokens`, not a fifth
   * component. Billed at the output rate; adding it to the others would
   * double-count. Absent (undefined) on runs predating the field.
   */
  reasoning_tokens?: number;
  total_tokens: number;
  input_cost: number;
  output_cost: number;
  cache_read_cost: number;
  cache_write_cost: number;
  total_cost: number;
}

/** Parsed `agent_end` payload — closes out a call with its cost and context use. */
export interface AgentEndPayload {
  cost?: number;
  /** Absent on runs predating the breakdown; `cost` alone survives there. */
  usage?: UsageBreakdown;
  /** Window occupancy after the final turn, and the model's ceiling. */
  context_tokens?: number;
  context_window?: number;
}

/**
 * Parsed `tool_call` payload — one event per real tool call, emitted when the
 * tool returns. `result_snippet` and `duration_ms` are absent when the coding
 * agent never reported a result.
 */
export interface ToolCallPayload {
  tool?: string;
  tool_call_id?: string;
  args?: Record<string, unknown>;
  result_snippet?: string;
  ok?: boolean;
  duration_ms?: number;
  agent?: string;
}

// ── API responses ────────────────────────────────────────────────────────────

/** GET /api/sessions */
export type SessionsResponse = SessionSummary[];

/** GET /api/sessions/:factory_id */
/**
 * What actually moved through a session, summed across every agent.
 *
 * Deliberately NOT the billed total: `sessions.total_tokens` also counts every
 * cached re-read, which is the same context charged again on each turn.
 */
export interface SessionUsage {
  /** Raw prompt tokens read for the first time: new input + cache writes. */
  read: number;
  /** Tokens generated. Each produced exactly once, so this needs no adjusting. */
  written: number;
}

export interface SessionDetail {
  session: Session;
  /** Derived from agent_end payloads, so historical runs have it too. */
  usage: SessionUsage;
  /** Ordered by seq. */
  phases: Phase[];
  /**
   * One entry per agent that has run OR is running under this factory_id — lane
   * labels come from here. Finished agents come from the agent_sessions table;
   * an agent still in flight has no row there yet, so its entry is built from
   * its agent_start event (coding_agent is null until it finishes).
   */
  agents: AgentSession[];
}

/**
 * GET /api/sessions/:factory_id/events?after=<rowid>&limit=500
 *
 * Poll with `after` = the cursor from the previous response. `cursor` is the
 * highest rowid in this page (or the `after` you sent, when the page is empty),
 * so it can be fed straight back in. `has_more` means the page hit the limit.
 */
export interface EventsPage {
  events: Event[];
  cursor: number;
  has_more: boolean;
}

/**
 * GET /api/sessions/:factory_id/agents/:agent/prompts
 *
 * The exact compiled prompts sent to an agent, read from
 * `{data_dir}/sessions/{factory_id}/{agent}/prompts/`. These live only as files —
 * the db has no copy. Either field is null when that file isn't on disk, which
 * is the normal state for an agent that never ran in this session, so a 200
 * with two nulls is a valid answer rather than an error.
 */
export interface AgentPrompts {
  system: string | null;
  user: string | null;
}

/** Alias matching the naming of the other endpoint payloads. */
export type PromptsResponse = AgentPrompts;

/** GET /api/sessions/:factory_id/envelopes */
export type EnvelopesResponse = Envelope[];

/** GET /api/sessions/:factory_id/gates */
export type GatesResponse = GateResult[];

/** GET /api/health */
export interface HealthResponse {
  ok: boolean;
  db: string;
  journal_mode: string;
  sessions: number;
}

export interface ApiError {
  error: string;
}

// ── Kaia's memory (engram) — proxied via /api/memory/* ─────────────────────

export interface MemoryEpisode {
  id: string | null;
  content: string;
  timestamp: string | null;
  actors: string[];
  tags: string[];
  salience: number | null;
  importance: number | null;
  summary_of: string | null;
  agent_id: string | null;
}

export interface MemoryFact {
  subject: string | null;
  predicate: string | null;
  object: string | null;
  valid_from: string | null;
  valid_to: string | null;
  recorded_at: string | null;
  superseded_at: string | null;
  confidence: number | null;
}

/** GET /api/memory/inspect */
export interface MemoryInspect {
  db: string;
  agent_id: string;
  counts: { episodes: number; facts: number; entities: number; edges: number };
  episodes: MemoryEpisode[];
  facts: MemoryFact[];
  entities: string[];
  agents: string[];
  inspect_at: string;
}

/** GET /api/memory/recall?q=...&k=...&mode=... */
export interface MemoryRecallResult {
  score: number;
  episode: MemoryEpisode;
}
export interface MemoryRecall {
  query: string;
  mode: string;
  results: MemoryRecallResult[];
}

/** GET /api/memory/timeline?entity=... */
export interface MemoryTimeline {
  entity: string;
  facts: MemoryFact[];
}

/** GET /api/memory/health */
export interface MemoryHealth {
  ok: boolean;
  db: string;
  episodes?: number;
  facts?: number;
  entities?: number;
}

// ── Decisions (the self-improving surface) — GET /api/decisions ────────────

export interface DecisionsBucket {
  diagnosis: string;
  model: string;
  count: number;
  last_seen: string;
  runs: string[];
  fix: string;
}

export interface DecisionsResponse {
  total_failed: number;
  decisions: DecisionsBucket[];
  generated_at: string;
}

// ── Statistics — GET /api/stats ─────────────────────────────────────────────

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
}

export interface VendorCost {
  cached_cost: number;
  total_cost: number;
  savings: number;
  savings_pct: number;
}

/** Where a model ran: own hardware (LM Studio/Ollama…) vs a cloud API. */
export type ModelKind = "local" | "online";

/** Rolled-up local/online usage, bucketed per model from agent_end events. */
export interface ProviderStat {
  /** Agent calls (agent_end events with usage). */
  events: number;
  /** Distinct sessions that used at least one model of this kind. */
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
  /** e.g. pi (local) or opencode (cloud). */
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

/** One catalog model in `StatsResponse.vendor_catalog` — rates + computed costs. */
export interface VendorModelCost extends VendorCost {
  id: string;
  name: string;
  provider: string;
  tier: 1 | 2 | 3;
  rank: number;
  tier_label: string;
  /** Input price per 1M tokens (published rate). */
  input_price: number;
  /** Output price per 1M tokens (published rate). */
  output_price: number;
  /** Cache-read price per 1M tokens (input_price × provider cache share). */
  cache_price: number;
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

export interface StatsResponse {
  totals: StatsTotals;
  usage: StatsUsage;
  cache_hit_ratio: number;
  avg_cache_hit_per_run: number;
  vendors: { gpt4o: VendorCost; gemini: VendorCost };
  /** All catalog models, each computed against the same usage. */
  vendor_catalog: VendorModelCost[];
  /** Local (own hardware) vs online (cloud API) usage split. */
  providers: ProviderBreakdown;
  by_chain: ChainStat[];
  by_model: ModelStat[];
  generated_at: string;
}

// ── Orchestrator chat (WayOfFactory `#/chat`) ────────────────────────────────

/** One tool invocation inside a Kaia message — rendered as a collapsible card. */
export interface ChatToolCall {
  /** Tool name as Pi reported it, e.g. "tickets_create" or "wayofteams.tickets_create". */
  tool: string;
  /** Input arguments passed to the tool. */
  args: Record<string, unknown>;
  /** Short result summary, e.g. "Created: WOTEAMS-421". */
  result?: string;
  /** Whether the call reported ok:false. Absent = ok. */
  ok?: boolean;
  /** Execution time in ms when the agent reported it. */
  ms?: number;
  /** Optional deep URL into WayOfTeams / the trace for the created resource. */
  link?: string;
  /** Collapsed by default — user expands to see args + result. */
  expanded?: boolean;
}

/** A factory session launched from chat — rendered as a special card. */
export interface SessionLaunch {
  factory_id: string;
  team: string;
  model: string;
  status: SessionStatus | null;
}

export type ChatMessageRole = "user" | "kaia" | "system" | "error";

/** One message in the orchestrator chat thread. */
export interface ChatMessage {
  id: string;
  ts: string;
  role: ChatMessageRole;
  /** Markdown body (Kaia) or plain text (user/system). */
  content: string;
  /** Tool calls embedded in a Kaia message — rendered as cards under the text. */
  tool_calls?: ChatToolCall[];
  /** Set when this Kaia message also launched a factory session. */
  session_launch?: SessionLaunch;
  /** While true the model is still generating this message. */
  streaming?: boolean;
  /** Lineage/footnote: which model answered this message. */
  model?: string;
}

/** A roster stack surfaced by GET /api/rosters. */
export interface RosterInfo {
  name: string;
  label: string;
  /** Primary surface: "local" (LM Studio/Ollama) or "cloud" (OpenAPI-compatible API). */
  surface: "local" | "cloud" | "hybrid";
  tier: string;
  /** Count of agents in the stack. */
  agent_count: number;
  /** The resolved orchestrator model id for this stack. */
  orchestrator_model: string;
  /** True when the orchestrator resolves to a sub-9B model (guarded by the UI). */
  weak_orchestrator: boolean;
  /** Per-role resolved model ids for the picker + side-panel agent list. */
  agents: { role: string; model: string }[];
  /** Short human description. */
  summary?: string;
}

/** One model in the orchestrator picker, from GET /api/models. */
export interface ModelInfo {
  id: string;
  name: string;
  provider: string;
  kind: "local" | "online";
  /** Estimated parameter count in billions, when known — the picker filters <9 for the orchestrator. */
  size_b?: number | null;
  /** True when the id suggests a sub-9B model (orchestrator guardrail). */
  weak: boolean;
  /** Whether this machine's pi catalog can resolve the model (chat surface). */
  available?: boolean;
}

/** Payload for POST /api/chat/message. */
export interface ChatMessageRequest {
  sessionId: string;
  content: string;
  /** Optional model override — the chat talks to Kaia on this model (defaults
   * to the orchestrator's cloud model when omitted). */
  model?: string;
}

/** Response for POST /api/chat/message. */
export interface ChatMessageResponse {
  message: ChatMessage;
}

/** Payload for POST /api/chat/session (factory launch). */
export interface SessionStartRequest {
  roster: string;
  /** Orchestrator model override — written as a session-scoped override, not persisted. */
  orchestratorModel?: string;
  task: string;
}

/** Response for POST /api/chat/session. */
export interface SessionStartResponse {
  session_id: string;
  roster: string;
  model: string;
  factory_id: string;
}

/** GET /api/chat/history */
export type ChatHistoryResponse = ChatMessage[];

/** GET /api/rosters */
export type RostersResponse = RosterInfo[];

/** GET /api/models */
export type ModelsResponse = ModelInfo[];

/** One local setting (WayOfTeams MCP key). value is NEVER returned raw — only masked. */
export interface SettingInfo {
  key: string;
  set: boolean;
  masked: string;
}

/** GET /api/settings */
export type SettingsResponse = SettingInfo[];

/** POST /api/settings/save — body { key, value } */
export interface SettingsSaveRequest {
  key: string;
  value: string;
}
